-- =====================================================
-- KSQLDB: Creación de Streams Base
-- Sistema de Detección de Fraude en Transacciones
-- =====================================================

-- Configuración de sesión
SET 'auto.offset.reset' = 'earliest';

-- =====================================================
-- STREAM: transactions_stream
-- Stream principal que lee del tópico de transacciones
-- Usa JSON_SR para obtener el schema del Schema Registry automáticamente
-- =====================================================
CREATE STREAM IF NOT EXISTS transactions_stream WITH (
    KAFKA_TOPIC = 'trx-fraud-transactions',
    VALUE_FORMAT = 'JSON_SR'
);

-- =====================================================
-- STREAM: transactions_stream_enriched
-- Stream enriquecido con conversión de timestamp y ubicación
-- =====================================================
CREATE STREAM IF NOT EXISTS transactions_stream_enriched WITH (
    KAFKA_TOPIC = 'transactions-enriched',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
) AS SELECT
    transaction_id,
    account_id,
    timestamp,
    amount,
    merchant_name,
    transaction_type,
    latitude,
    longitude,
    CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING)) as location,
    channel,
    status,
    PARSE_TIMESTAMP(timestamp, 'yyyy-MM-dd HH:mm:ss') as transaction_timestamp,
    TIMESTAMPTOSTRING(ROWTIME, 'yyyy-MM-dd HH:mm:ss') as processing_time
FROM transactions_stream
EMIT CHANGES;

-- Verificación del stream
-- Para ejecutar manualmente: SELECT * FROM transactions_stream EMIT CHANGES LIMIT 5;

