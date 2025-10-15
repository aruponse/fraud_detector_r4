-- =====================================================
-- KSQLDB: Reglas de Detección de Fraude
-- Sistema de Detección de Fraude en Transacciones
-- =====================================================

-- Configuración de sesión
SET 'auto.offset.reset' = 'earliest';

-- =====================================================
-- REGLA 1: Transacciones de Alto Valor
-- Detecta transacciones superiores a $10,000
-- =====================================================
CREATE STREAM IF NOT EXISTS high_value_transactions WITH (
    KAFKA_TOPIC = 'fraud-high-value',
    VALUE_FORMAT = 'JSON_SR'
) AS SELECT
    transaction_id,
    account_id,
    amount,
    timestamp,
    merchant_name,
    transaction_type,
    latitude,
    longitude,
    channel,
    CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING)) as location,
    'HIGH_VALUE' as fraud_type,
    CONCAT('Transacción de alto valor: $', CAST(amount AS STRING), ' excede el umbral de $10,000') as reason,
    'HIGH' as severity
FROM transactions_stream
WHERE amount > 10000
EMIT CHANGES;

-- =====================================================
-- REGLA 2: Frecuencia Anormal de Transacciones
-- Detecta más de 5 transacciones en una ventana de 5 minutos
-- =====================================================
CREATE TABLE IF NOT EXISTS transaction_frequency WITH (
    KAFKA_TOPIC = 'fraud-high-frequency-table',
    VALUE_FORMAT = 'JSON_SR'
) AS SELECT
    account_id,
    'HIGH_FREQUENCY' as fraud_type,
    'HIGH' as severity,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount,
    COLLECT_LIST(transactions_stream.transaction_id) as transaction_ids,
    COLLECT_LIST(CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) as locations,
    COLLECT_LIST(merchant_name) as merchants,
    COLLECT_LIST(channel) as channels,
    CONCAT('Alta frecuencia: ', CAST(COUNT(*) AS STRING), ' transacciones en 5 minutos') as reason
FROM transactions_stream
WINDOW TUMBLING (SIZE 5 MINUTES)
GROUP BY account_id
HAVING COUNT(*) > 5
EMIT CHANGES;

-- =====================================================
-- REGLA 3: Múltiples Ubicaciones Simultáneas
-- Detecta más de 2 ubicaciones diferentes en 10 minutos
-- =====================================================
CREATE TABLE IF NOT EXISTS multiple_locations WITH (
    KAFKA_TOPIC = 'fraud-multiple-locations-table',
    VALUE_FORMAT = 'JSON_SR'
) AS SELECT
    account_id,
    'MULTIPLE_LOCATIONS' as fraud_type,
    'HIGH' as severity,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as transaction_count,
    COUNT_DISTINCT(CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) as unique_locations,
    COLLECT_SET(CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) as locations,
    COLLECT_LIST(transactions_stream.transaction_id) as transaction_ids,
    SUM(amount) as total_amount,
    CONCAT('Múltiples ubicaciones: ', CAST(COUNT_DISTINCT(CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) AS STRING), ' ubicaciones en 10 minutos') as reason
FROM transactions_stream
WINDOW TUMBLING (SIZE 10 MINUTES)
GROUP BY account_id
HAVING COUNT_DISTINCT(CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) > 2
EMIT CHANGES;

-- =====================================================
-- REGLA 4: Cambios Drásticos de Comportamiento
-- Detecta transacciones que exceden 3x el promedio histórico
-- =====================================================
CREATE TABLE IF NOT EXISTS account_avg_amount WITH (
    KAFKA_TOPIC = 'account-avg-amount-table',
    VALUE_FORMAT = 'JSON_SR',
    PARTITIONS = 3
) AS SELECT
    account_id,
    AVG(amount) as avg_amount,
    MAX(amount) as max_amount,
    MIN(amount) as min_amount,
    COUNT(*) as transaction_count
FROM transactions_stream
WINDOW TUMBLING (SIZE 1 HOUR)
GROUP BY account_id
EMIT CHANGES;

-- =====================================================
-- REGLA 5: Transacciones en Horarios Inusuales
-- Detecta transacciones en horarios poco comunes (2AM - 5AM)
-- =====================================================
CREATE STREAM IF NOT EXISTS unusual_time_alerts WITH (
    KAFKA_TOPIC = 'fraud-unusual-time',
    VALUE_FORMAT = 'JSON_SR'
) AS SELECT
    transaction_id,
    account_id,
    amount,
    timestamp,
    merchant_name,
    transaction_type,
    latitude,
    longitude,
    channel,
    CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING)) as location,
    CAST(SUBSTRING(timestamp, 12, 2) AS INTEGER) as hour_of_day,
    'UNUSUAL_TIME' as fraud_type,
    CONCAT('Transacción en horario inusual: ', SUBSTRING(timestamp, 12, 2), ':00 hrs') as reason,
    'LOW' as severity
FROM transactions_stream
WHERE CAST(SUBSTRING(timestamp, 12, 2) AS INTEGER) >= 2 
  AND CAST(SUBSTRING(timestamp, 12, 2) AS INTEGER) <= 5
EMIT CHANGES;

-- =====================================================
-- STREAM CONSOLIDADO: fraud_alerts
-- Consolida alertas de streams
-- =====================================================
CREATE STREAM IF NOT EXISTS fraud_alerts_consolidated WITH (
    KAFKA_TOPIC = 'fraud-alerts',
    VALUE_FORMAT = 'JSON_SR',
    PARTITIONS = 3
) AS SELECT
    transaction_id,
    account_id,
    amount,
    timestamp,
    merchant_name,
    transaction_type,
    latitude,
    longitude,
    channel,
    location,
    fraud_type,
    reason,
    severity
FROM high_value_transactions
EMIT CHANGES;

-- =====================================================
-- TABLA: Resumen de alertas por cuenta
-- =====================================================
CREATE TABLE IF NOT EXISTS fraud_summary_by_account WITH (
    KAFKA_TOPIC = 'fraud-summary-by-account',
    VALUE_FORMAT = 'JSON_SR',
    PARTITIONS = 3
) AS SELECT
    account_id,
    COUNT(*) as total_alerts,
    SUM(amount) as total_fraud_amount,
    COLLECT_LIST(fraud_type) as fraud_types,
    MAX(ROWTIME) as last_alert_time
FROM fraud_alerts_consolidated
GROUP BY account_id
EMIT CHANGES;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================
-- 1. Las tablas TRANSACTION_FREQUENCY, MULTIPLE_LOCATIONS y ACCOUNT_AVG_AMOUNT
--    son tablas windowed que contienen agregaciones.
--    Para convertirlas en alertas, consumir directamente de sus topics:
--    - fraud-high-frequency-table
--    - fraud-multiple-locations-table
--    - account-avg-amount-table (para análisis)
--
-- 2. Para consultar estas tablas en tiempo real:
--    SELECT * FROM transaction_frequency EMIT CHANGES;
--    SELECT * FROM multiple_locations EMIT CHANGES;
--
-- 3. Estas alertas se persisten en PostgreSQL, en la tabla fraud_alerts
-- =====================================================
