-- =====================================================
-- Limpieza de Streams y Tables Existentes
-- =====================================================

-- Eliminar streams (orden inverso a la creación)
DROP STREAM IF EXISTS fraud_alerts_consolidated DELETE TOPIC;
DROP STREAM IF EXISTS unusual_time_alerts DELETE TOPIC;
DROP STREAM IF EXISTS behavior_change_alerts DELETE TOPIC;
DROP STREAM IF EXISTS multiple_locations_alerts DELETE TOPIC;
DROP STREAM IF EXISTS high_frequency_alerts DELETE TOPIC;
DROP STREAM IF EXISTS high_value_transactions DELETE TOPIC;
DROP STREAM IF EXISTS transactions_stream_enriched DELETE TOPIC;
DROP STREAM IF EXISTS transactions_stream DELETE TOPIC;

-- Eliminar tables
DROP TABLE IF EXISTS fraud_summary_by_account DELETE TOPIC;
DROP TABLE IF EXISTS account_avg_amount DELETE TOPIC;
DROP TABLE IF EXISTS multiple_locations DELETE TOPIC;
DROP TABLE IF EXISTS transaction_frequency DELETE TOPIC;

