-- =====================================================
-- KSQLDB: Agregaciones y Estadísticas
-- Sistema de Detección de Fraude en Transacciones
-- =====================================================

-- Configuración de sesión
SET 'auto.offset.reset' = 'earliest';

-- =====================================================
-- TABLA 1: account_statistics
-- Estadísticas por cuenta en ventanas de 1 hora
-- =====================================================
CREATE TABLE IF NOT EXISTS account_statistics WITH (
    KAFKA_TOPIC = 'account-statistics',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    account_id,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as total_transactions,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount,
    MAX(amount) as max_amount,
    MIN(amount) as min_amount,
    STDDEV_SAMP(amount) as stddev_amount,
    COUNT_DISTINCT(CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) as unique_locations,
    COUNT_DISTINCT(merchant_name) as unique_merchants,
    COUNT_DISTINCT(channel) as unique_channels,
    COLLECT_SET(CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) as locations,
    COLLECT_SET(merchant_name) as merchants,
    COLLECT_SET(channel) as channels,
    COLLECT_LIST(transaction_id) as transaction_ids
FROM transactions_stream
WINDOW TUMBLING (SIZE 1 HOUR)
GROUP BY account_id
EMIT CHANGES;

-- =====================================================
-- TABLA 2: merchant_statistics
-- Estadísticas por comerciante en ventanas de 1 hora
-- =====================================================
CREATE TABLE IF NOT EXISTS merchant_statistics WITH (
    KAFKA_TOPIC = 'merchant-statistics',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    merchant_name,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as transaction_count,
    SUM(amount) as total_volume,
    AVG(amount) as avg_transaction,
    MAX(amount) as max_transaction,
    MIN(amount) as min_transaction,
    COUNT_DISTINCT(account_id) as unique_accounts,
    COUNT_DISTINCT(CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) as unique_locations,
    COUNT_DISTINCT(channel) as unique_channels,
    COLLECT_SET(account_id) as accounts,
    COLLECT_SET(channel) as channels
FROM transactions_stream
WINDOW TUMBLING (SIZE 1 HOUR)
GROUP BY merchant_name
EMIT CHANGES;

-- =====================================================
-- TABLA 3: location_statistics
-- Estadísticas por ubicación en ventanas de 1 hora
-- =====================================================
CREATE TABLE IF NOT EXISTS location_statistics WITH (
    KAFKA_TOPIC = 'location-statistics',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING)) as location,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as transaction_count,
    SUM(amount) as total_volume,
    AVG(amount) as avg_transaction,
    MAX(amount) as max_transaction,
    COUNT_DISTINCT(account_id) as unique_accounts,
    COUNT_DISTINCT(merchant_name) as unique_merchants,
    COUNT_DISTINCT(channel) as unique_channels,
    COLLECT_SET(account_id) as accounts,
    COLLECT_SET(merchant_name) as merchants,
    COLLECT_SET(channel) as channels
FROM transactions_stream
WINDOW TUMBLING (SIZE 1 HOUR)
GROUP BY CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))
EMIT CHANGES;

-- =====================================================
-- TABLA 4: transaction_type_statistics
-- Estadísticas por tipo de transacción
-- =====================================================
CREATE TABLE IF NOT EXISTS transaction_type_statistics WITH (
    KAFKA_TOPIC = 'transaction-type-statistics',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    transaction_type,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as transaction_count,
    SUM(amount) as total_volume,
    AVG(amount) as avg_amount,
    MAX(amount) as max_amount,
    MIN(amount) as min_amount,
    COUNT_DISTINCT(account_id) as unique_accounts
FROM transactions_stream
WINDOW TUMBLING (SIZE 1 HOUR)
GROUP BY transaction_type
EMIT CHANGES;

-- =====================================================
-- TABLA 5: real_time_volume
-- Volumen total en tiempo real (ventana de 5 minutos)
-- =====================================================
CREATE TABLE IF NOT EXISTS real_time_volume WITH (
    KAFKA_TOPIC = 'real-time-volume',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    'ALL' as metric_key,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as total_transactions,
    SUM(amount) as total_volume,
    AVG(amount) as avg_amount,
    MAX(amount) as max_amount,
    MIN(amount) as min_amount,
    COUNT_DISTINCT(account_id) as unique_accounts,
    COUNT_DISTINCT(merchant_name) as unique_merchants,
    COUNT_DISTINCT(CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) as unique_locations,
    COUNT_DISTINCT(channel) as unique_channels
FROM transactions_stream
WINDOW TUMBLING (SIZE 5 MINUTES)
GROUP BY 'ALL'
EMIT CHANGES;

-- =====================================================
-- TABLA 6: high_value_merchants
-- Comerciantes con alto volumen de transacciones
-- =====================================================
CREATE TABLE IF NOT EXISTS high_value_merchants WITH (
    KAFKA_TOPIC = 'high-value-merchants',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    merchant_name,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as transaction_count,
    SUM(amount) as total_volume,
    AVG(amount) as avg_transaction,
    COUNT_DISTINCT(account_id) as unique_accounts,
    COUNT_DISTINCT(channel) as unique_channels
FROM transactions_stream
WINDOW TUMBLING (SIZE 1 HOUR)
GROUP BY merchant_name
HAVING SUM(amount) > 50000
EMIT CHANGES;

-- =====================================================
-- TABLA 7: active_accounts_hourly
-- Cuentas activas por hora
-- =====================================================
CREATE TABLE IF NOT EXISTS active_accounts_hourly WITH (
    KAFKA_TOPIC = 'active-accounts-hourly',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    account_id,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as transaction_count,
    SUM(amount) as total_spent,
    COLLECT_LIST(merchant_name) as merchants_visited,
    COLLECT_LIST(CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) as locations_visited,
    COLLECT_LIST(channel) as channels_used,
    EARLIEST_BY_OFFSET(timestamp) as first_transaction_time,
    LATEST_BY_OFFSET(timestamp) as last_transaction_time
FROM transactions_stream
WINDOW TUMBLING (SIZE 1 HOUR)
GROUP BY account_id
EMIT CHANGES;

-- =====================================================
-- TABLA 8: velocity_check
-- Verificación de velocidad (transacciones en 1 minuto)
-- =====================================================
CREATE TABLE IF NOT EXISTS velocity_check WITH (
    KAFKA_TOPIC = 'velocity-check',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    account_id,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as transactions_per_minute,
    SUM(amount) as amount_per_minute,
    COLLECT_LIST(CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) as locations,
    COLLECT_LIST(merchant_name) as merchants,
    COLLECT_LIST(channel) as channels
FROM transactions_stream
WINDOW TUMBLING (SIZE 1 MINUTE)
GROUP BY account_id
EMIT CHANGES;

-- =====================================================
-- STREAM: Alertas de velocidad excesiva
-- =====================================================
CREATE STREAM IF NOT EXISTS velocity_alerts WITH (
    KAFKA_TOPIC = 'fraud-velocity',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    account_id,
    transactions_per_minute,
    amount_per_minute,
    locations,
    merchants,
    'VELOCITY_CHECK' as fraud_type,
    CONCAT('Velocidad excesiva: ', CAST(transactions_per_minute AS STRING), ' transacciones por minuto') as reason,
    'HIGH' as severity,
    TIMESTAMPTOSTRING(ROWTIME, 'yyyy-MM-dd HH:mm:ss') as alert_timestamp
FROM velocity_check
WHERE transactions_per_minute > 3
EMIT CHANGES;

-- =====================================================
-- TABLA 9: Patrones por día de la semana
-- =====================================================
CREATE TABLE IF NOT EXISTS daily_patterns WITH (
    KAFKA_TOPIC = 'daily-patterns',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    DAYOFWEEK(PARSE_TIMESTAMP(timestamp, 'yyyy-MM-dd HH:mm:ss')) as day_of_week,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as transaction_count,
    SUM(amount) as total_volume,
    AVG(amount) as avg_amount,
    COUNT_DISTINCT(account_id) as unique_accounts
FROM transactions_stream
WINDOW TUMBLING (SIZE 1 DAY)
GROUP BY DAYOFWEEK(PARSE_TIMESTAMP(timestamp, 'yyyy-MM-dd HH:mm:ss'))
EMIT CHANGES;

-- =====================================================
-- TABLA 10: Transacciones por status
-- =====================================================
CREATE TABLE IF NOT EXISTS transactions_by_status WITH (
    KAFKA_TOPIC = 'transactions-by-status',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    status,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount
FROM transactions_stream
WINDOW TUMBLING (SIZE 15 MINUTES)
GROUP BY status
EMIT CHANGES;

-- =====================================================
-- TABLA 11: channel_statistics
-- Estadísticas por canal de transacción
-- =====================================================
CREATE TABLE IF NOT EXISTS channel_statistics WITH (
    KAFKA_TOPIC = 'channel-statistics',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    channel,
    WINDOWSTART as window_start,
    WINDOWEND as window_end,
    COUNT(*) as transaction_count,
    SUM(amount) as total_volume,
    AVG(amount) as avg_amount,
    MAX(amount) as max_amount,
    MIN(amount) as min_amount,
    COUNT_DISTINCT(account_id) as unique_accounts,
    COUNT_DISTINCT(merchant_name) as unique_merchants
FROM transactions_stream
WINDOW TUMBLING (SIZE 1 HOUR)
GROUP BY channel
EMIT CHANGES;

-- =====================================================
-- Consultas útiles para verificación
-- =====================================================
-- Ver estadísticas de cuenta en tiempo real:
-- SELECT * FROM account_statistics EMIT CHANGES;

-- Ver comerciantes más activos:
-- SELECT merchant_name, transaction_count, total_volume FROM merchant_statistics EMIT CHANGES;

-- Ver ubicaciones con más actividad:
-- SELECT location, transaction_count, total_volume FROM location_statistics EMIT CHANGES;

-- Ver volumen en tiempo real:
-- SELECT * FROM real_time_volume EMIT CHANGES;

-- Ver alertas de velocidad:
-- SELECT * FROM velocity_alerts EMIT CHANGES;

-- Ver estadísticas por canal:
-- SELECT * FROM channel_statistics EMIT CHANGES;

