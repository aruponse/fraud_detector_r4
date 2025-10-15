#!/bin/bash
# Script: validate-data-flow.sh
# Valida el flujo completo de datos en el pipeline

set -e

# Cargar variables de entorno
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuración
CONNECT_URL="${KAFKA_CONNECT_URL:-http://localhost:8083}"
KSQL_URL="${KSQLDB_SERVER_URL:-http://localhost:8088}"
TRANSACTIONS_TOPIC="${TRANSACTIONS_TOPIC:-trx-fraud-transactions}"

# Funciones de impresión
print_banner() {
    echo -e "${CYAN}"
    echo "=========================================="
    echo "  $1"
    echo "=========================================="
    echo -e "${NC}"
}

print_info() {
    echo -e "${BLUE}  $1${NC}"
}

print_success() {
    echo -e "${GREEN} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  $1${NC}"
}

print_error() {
    echo -e "${RED} $1${NC}"
}

# Función para contar mensajes en un tópico
count_topic_messages() {
    local topic=$1
    local count=$(docker exec fraud-kafka kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list localhost:9092 \
        --topic "$topic" \
        --time -1 2>/dev/null | \
        awk -F ':' '{sum += $3} END {print sum}')
    echo ${count:-0}
}

# Función para listar streams de ksqlDB
list_ksql_streams() {
    curl -sf -X POST "$KSQL_URL/ksql" \
        -H "Content-Type: application/vnd.ksql.v1+json" \
        -d '{"ksql":"SHOW STREAMS;","streamsProperties":{}}' | \
        python3 -c "import sys, json; data=json.load(sys.stdin); streams=data[0].get('streams',[]); [print(s['name']) for s in streams]" 2>/dev/null || echo ""
}

# Función para listar tablas de ksqlDB
list_ksql_tables() {
    curl -sf -X POST "$KSQL_URL/ksql" \
        -H "Content-Type: application/vnd.ksql.v1+json" \
        -d '{"ksql":"SHOW TABLES;","streamsProperties":{}}' | \
        python3 -c "import sys, json; data=json.load(sys.stdin); tables=data[0].get('tables',[]); [print(t['name']) for t in tables]" 2>/dev/null || echo ""
}

# Banner principal
clear
print_banner "Validación del Flujo de Datos"
echo ""

# 1. Verificar archivos CSV
print_info "Paso 1: Verificando archivos CSV..."
input_files=$(docker exec fraud-kafka-connect ls -1 /data/input/*.csv 2>/dev/null | wc -l)
processed_files=$(docker exec fraud-kafka-connect find /data/processed -name "*.csv" 2>/dev/null | wc -l)
error_files=$(docker exec fraud-kafka-connect ls -1 /data/error/ 2>/dev/null | wc -l)

echo "    Archivos en input: $input_files"
echo "    Archivos procesados: $processed_files"
echo "    Archivos con error: $error_files"

if [ "$processed_files" -gt 0 ]; then
    print_success "Archivos CSV procesados correctamente"
else
    print_warning "No se han procesado archivos aún"
fi
echo ""

# 2. Verificar conectores
print_info "Paso 2: Verificando conectores..."
connectors=$(curl -sf "$CONNECT_URL/connectors" | python3 -m json.tool 2>/dev/null)
connector_count=$(echo "$connectors" | grep -o '"csv-source-connector"' | wc -l)

if [ "$connector_count" -gt 0 ]; then
    csv_status=$(curl -sf "$CONNECT_URL/connectors/csv-source-connector/status" | \
        python3 -c "import sys, json; data=json.load(sys.stdin); print(data['connector']['state'])" 2>/dev/null)
    echo "    CSV Source Connector: $csv_status"
    
    if [ "$csv_status" = "RUNNING" ]; then
        print_success "CSV Source Connector operacional"
    else
        print_warning "CSV Source Connector no está en RUNNING"
    fi
else
    print_warning "CSV Source Connector no está desplegado"
fi
echo ""

# 3. Verificar tópicos de Kafka
print_info "Paso 3: Verificando tópicos de Kafka..."
transactions_count=$(count_topic_messages "$TRANSACTIONS_TOPIC")
fraud_alerts_count=$(count_topic_messages "fraud-alerts")
fraud_high_value_count=$(count_topic_messages "fraud-high-value")

echo "    Mensajes en $TRANSACTIONS_TOPIC: $transactions_count"
echo "    Mensajes en fraud-alerts: $fraud_alerts_count"
echo "    Mensajes en fraud-high-value: $fraud_high_value_count"

if [ "$transactions_count" -gt 0 ]; then
    print_success "Transacciones publicadas en Kafka: $transactions_count"
else
    print_warning "No hay transacciones en Kafka"
fi
echo ""

# 4. Verificar streams de ksqlDB
print_info "Paso 4: Verificando streams de ksqlDB..."
streams=$(list_ksql_streams)
stream_count=$(echo "$streams" | grep -v "^$" | wc -l)

echo "    Total de streams: $stream_count"
echo "$streams" | while read stream; do
    [ -n "$stream" ] && echo "      - $stream"
done

if [ "$stream_count" -gt 0 ]; then
    print_success "Streams de ksqlDB creados: $stream_count"
else
    print_warning "No hay streams de ksqlDB creados"
fi
echo ""

# 5. Verificar tablas de ksqlDB
print_info "Paso 5: Verificando tablas de ksqlDB..."
tables=$(list_ksql_tables)
table_count=$(echo "$tables" | grep -v "^$" | wc -l)

echo "    Total de tablas: $table_count"
echo "$tables" | while read table; do
    [ -n "$table" ] && echo "      - $table"
done

if [ "$table_count" -gt 0 ]; then
    print_success "Tablas de ksqlDB creadas: $table_count"
else
    print_info "No hay tablas de agregación creadas aún"
fi
echo ""

# 6. Verificar PostgreSQL
print_info "Paso 6: Verificando PostgreSQL..."
pg_tables=$(docker exec fraud-postgres psql -U kafka_user -d fraud_detection -t -c "\dt" 2>/dev/null | grep -c "transactions\|fraud_alerts" || echo "0")
pg_transaction_count=$(docker exec fraud-postgres psql -U kafka_user -d fraud_detection -t -c "SELECT COUNT(*) FROM transactions;" 2>/dev/null | tr -d ' ' || echo "0")

echo "    Tablas en PostgreSQL: $pg_tables"
echo "    Registros en transactions: $pg_transaction_count"

if [ "$pg_tables" -gt 0 ]; then
    print_success "Tablas de PostgreSQL creadas"
    
    # Verificar tipos de datos si hay registros
    if [ "$pg_transaction_count" -gt 0 ]; then
        echo ""
        print_info "Verificando tipos de datos en PostgreSQL..."
        
        # Verificar que el campo timestamp es realmente TIMESTAMP
        timestamp_type=$(docker exec fraud-postgres psql -U kafka_user -d fraud_detection -t -c "\
            SELECT data_type FROM information_schema.columns \
            WHERE table_name='transactions' AND column_name='timestamp';" 2>/dev/null | tr -d ' ' || echo "unknown")
        
        # Verificar muestra de datos
        sample_data=$(docker exec fraud-postgres psql -U kafka_user -d fraud_detection -t -c "\
            SELECT transaction_id, account_id, timestamp, amount \
            FROM transactions LIMIT 1;" 2>/dev/null || echo "")
        
        echo "    Tipo de campo timestamp: $timestamp_type"
        if [ "$timestamp_type" = "timestampwithouttime zone" ] || [ "$timestamp_type" = "timestamp" ]; then
            print_success "Campo timestamp tiene tipo correcto: $timestamp_type"
        else
            print_warning "Campo timestamp tiene tipo inesperado: $timestamp_type"
        fi
        
        if [ -n "$sample_data" ]; then
            echo ""
            print_info "Muestra de datos en PostgreSQL:"
            echo "$sample_data"
        fi
    fi
else
    print_warning "Tablas de PostgreSQL no encontradas"
fi
echo ""

# Resumen Final
print_banner "Resumen de Validación"
echo ""

total_checks=6
passed=0

# Check 1: CSV procesados
[ "$processed_files" -gt 0 ] && passed=$((passed + 1))

# Check 2: Connector running
[ "$csv_status" = "RUNNING" ] && passed=$((passed + 1))

# Check 3: Mensajes en Kafka
[ "$transactions_count" -gt 0 ] && passed=$((passed + 1))

# Check 4: Streams creados
[ "$stream_count" -gt 0 ] && passed=$((passed + 1))

# Check 5: Tablas en PostgreSQL
[ "$pg_tables" -gt 0 ] && passed=$((passed + 1))

# Check 6: Datos en PostgreSQL
[ "$pg_transaction_count" -gt 0 ] && passed=$((passed + 1))

echo "Validaciones pasadas: $passed/$total_checks"
echo ""

if [ "$passed" -ge 4 ]; then
    print_success "El pipeline está funcionando correctamente"
    echo ""
    echo "Siguiente paso: Verificar detección de fraude"
    echo "  curl -s http://localhost:8088/ksql -H 'Content-Type: application/vnd.ksql.v1+json' \\"
    echo "    -d '{\"ksql\":\"SHOW QUERIES;\"}' | python3 -m json.tool"
elif [ "$passed" -ge 2 ]; then
    print_warning "El pipeline está parcialmente funcional"
    echo ""
    echo "Revisa los logs para más detalles:"
    echo "  docker logs fraud-kafka-connect | tail -50"
    echo "  docker logs fraud-ksqldb-server | tail -50"
else
    print_error "El pipeline tiene problemas significativos"
    echo ""
    echo "Revisa la configuración y logs de servicios"
fi

echo ""
exit 0


