-- =====================================================
-- Script de Inicialización de Base de Datos
-- Sistema de Detección de Fraude en Transacciones
-- =====================================================

-- Configuración de zona horaria
SET timezone = 'UTC';

-- =====================================================
-- TABLA: transactions
-- Almacena todas las transacciones procesadas
-- =====================================================
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id VARCHAR(50) PRIMARY KEY,
    account_id VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    merchant_name VARCHAR(100),
    transaction_type VARCHAR(50),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    channel VARCHAR(20),
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para optimizar consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON transactions(timestamp);
CREATE INDEX IF NOT EXISTS idx_transactions_amount ON transactions(amount);
CREATE INDEX IF NOT EXISTS idx_transactions_merchant_name ON transactions(merchant_name);
CREATE INDEX IF NOT EXISTS idx_transactions_latitude_longitude ON transactions(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_transactions_channel ON transactions(channel);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);

-- Índice compuesto para consultas por cuenta y tiempo
CREATE INDEX IF NOT EXISTS idx_transactions_account_timestamp ON transactions(account_id, timestamp DESC);

-- =====================================================
-- TABLA: fraud_alerts
-- Almacena todas las alertas de fraude detectadas
-- =====================================================
CREATE TABLE IF NOT EXISTS fraud_alerts (
    alert_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(50),
    account_id VARCHAR(50),
    amount DOUBLE PRECISION,
    timestamp VARCHAR(50),
    merchant_name VARCHAR(100),
    transaction_type VARCHAR(50),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    channel VARCHAR(20),
    location VARCHAR(100),
    fraud_type VARCHAR(50),
    reason TEXT,
    severity VARCHAR(20),
    hour_of_day INTEGER,
    transaction_count BIGINT,
    total_amount DOUBLE PRECISION,
    avg_amount DOUBLE PRECISION,
    unique_locations INTEGER,
    window_start BIGINT,
    window_end BIGINT,
    alert_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para análisis de fraude
CREATE INDEX IF NOT EXISTS idx_fraud_alerts_account_id ON fraud_alerts(account_id);
CREATE INDEX IF NOT EXISTS idx_fraud_alerts_transaction_id ON fraud_alerts(transaction_id);
CREATE INDEX IF NOT EXISTS idx_fraud_alerts_fraud_type ON fraud_alerts(fraud_type);
CREATE INDEX IF NOT EXISTS idx_fraud_alerts_severity ON fraud_alerts(severity);

-- =====================================================
-- GRANTS Y PERMISOS
-- =====================================================
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO kafka_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO kafka_user;
