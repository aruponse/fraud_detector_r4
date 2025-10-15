#!/bin/bash
# Script para resetear completamente ksqlDB y recrear streams

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}  $1${NC}"
}

print_success() {
    echo -e "${GREEN} $1${NC}"
}

echo "========================================"
echo "  Reset Completo de ksqlDB"
echo "========================================"
echo ""

print_info "Deteniendo ksqlDB..."
docker stop fraud-ksqldb-server fraud-ksqldb-cli

print_info "Elimin ando volúmenes de ksqlDB..."
docker volume rm fraud_detector_r4_ksqldb_data 2>/dev/null || echo "  Volumen no encontrado"

print_info "Eliminando topics de ksqlDB..."
docker exec fraud-kafka kafka-topics --bootstrap-server localhost:9092 --delete --topic ksql_service_fraud_detectionksql_processing_log 2>/dev/null || true
docker exec fraud-kafka kafka-topics --bootstrap-server localhost:9092 --delete --topic _confluent-ksql-ksql_service_fraud_detection_command_topic 2>/dev/null || true

print_info "Reiniciando ksqlDB..."
docker start fraud-ksqldb-server fraud-ksqldb-cli

print_info "Esperando 60 segundos para que ksqlDB esté listo..."
sleep 60

print_success "ksqlDB reseteado completamente"
echo ""

print_info "Ahora ejecuta:"
echo "  docker exec fraud-ksqldb-server bash -c 'ksql http://localhost:8088 < /etc/ksqldb/scripts/01-create-streams.sql'"
echo "  docker exec fraud-ksqldb-server bash -c 'ksql http://localhost:8088 < /etc/ksqldb/scripts/02-fraud-detection.sql'"
echo ""

