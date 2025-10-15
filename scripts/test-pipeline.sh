#!/bin/bash
# Script: test-pipeline.sh
# Ejecuta una prueba completa del pipeline con datos de muestra

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
NUM_TRANSACTIONS="${1:-50}"
FRAUD_RATE="${2:-0.10}"
TEST_FILE="data/input/test_pipeline_$(date +%Y%m%d_%H%M%S).csv"

# Funciones
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

# Banner
clear
print_banner "Prueba Completa del Pipeline"
echo ""
print_info "Configuración de la prueba:"
echo "    Transacciones: $NUM_TRANSACTIONS"
echo "    Tasa de fraude: $(echo "$FRAUD_RATE * 100" | bc)%"
echo "    Archivo: $TEST_FILE"
echo ""

# Paso 1: Generar datos de prueba
print_info "Paso 1: Generando datos de prueba..."
if python3 "$PROJECT_ROOT/generate_test_data.py" -t "$NUM_TRANSACTIONS" --fraud-rate "$FRAUD_RATE" -o "$PROJECT_ROOT/$TEST_FILE" > /dev/null 2>&1; then
    print_success "Datos generados: $TEST_FILE"
else
    print_error "Error al generar datos"
    exit 1
fi
echo ""

# Paso 2: Verificar que el archivo existe
print_info "Paso 2: Verificando archivo..."
if [ -f "$PROJECT_ROOT/$TEST_FILE" ]; then
    line_count=$(wc -l < "$PROJECT_ROOT/$TEST_FILE")
    echo "    Líneas en el archivo: $line_count"
    print_success "Archivo verificado"
else
    print_error "Archivo no encontrado"
    exit 1
fi
echo ""

# Paso 3: Esperar a que el conector procese el archivo
print_info "Paso 3: Esperando procesamiento del conector..."
sleep 5
echo -n "    Esperando"
for i in {1..10}; do
    echo -n "."
    sleep 1
done
echo ""

# Verificar si se procesó
if docker exec fraud-kafka-connect ls "/data/input/$( basename $TEST_FILE)" > /dev/null 2>&1; then
    print_warning "Archivo aún en /data/input (procesando...)"
elif docker exec fraud-kafka-connect find /data/processed -name "$(basename $TEST_FILE)" | grep -q "$(basename $TEST_FILE)"; then
    print_success "Archivo procesado y movido a /data/processed"
else
    print_warning "Estado del archivo desconocido"
fi
echo ""

# Paso 4: Verificar mensajes en Kafka
print_info "Paso 4: Verificando mensajes en Kafka..."
sleep 3
transactions_count=$(docker exec fraud-kafka kafka-run-class kafka.tools.GetOffsetShell \
    --broker-list localhost:9092 \
    --topic trx-fraud-transactions \
    --time -1 2>/dev/null | \
    awk -F ':' '{sum += $3} END {print sum}')

echo "    Total de mensajes en trx-fraud-transactions: $transactions_count"

if [ "$transactions_count" -gt 0 ]; then
    print_success "Transacciones publicadas en Kafka"
    
    # Mostrar muestra
    echo ""
    print_info "Muestra de transacción (con schema):"
    docker exec fraud-kafka kafka-console-consumer \
        --bootstrap-server localhost:9092 \
        --topic trx-fraud-transactions \
        --from-beginning \
        --max-messages 1 \
        --timeout-ms 3000 2>/dev/null | \
        python3 -m json.tool 2>/dev/null | head -20
        
    # Verificar que el mensaje tiene schema
    echo ""
    print_info "Verificando schema en el mensaje..."
    has_schema=$(docker exec fraud-kafka kafka-console-consumer \
        --bootstrap-server localhost:9092 \
        --topic trx-fraud-transactions \
        --from-beginning \
        --max-messages 1 \
        --timeout-ms 3000 2>/dev/null | \
        python3 -c "import sys, json; data=json.loads(sys.stdin.read()); print('schema' in data)" 2>/dev/null || echo "false")
    
    if [ "$has_schema" = "True" ]; then
        print_success "Los mensajes incluyen schema JSON"
    else
        print_warning "Los mensajes pueden no incluir schema (verificar configuración)"
    fi
else
    print_warning "No hay mensajes en Kafka"
fi
echo ""

# Paso 5: Verificar streams de ksqlDB
print_info "Paso 5: Verificando streams de ksqlDB..."
streams=$(curl -sf -X POST "$KSQL_URL/ksql" \
    -H "Content-Type: application/vnd.ksql.v1+json" \
    -d '{"ksql":"SHOW STREAMS;","streamsProperties":{}}' | \
    python3 -c "import sys, json; data=json.load(sys.stdin); streams=data[0].get('streams',[]); print(len(streams))" 2>/dev/null || echo "0")

echo "    Streams activos: $streams"

if [ "$streams" -gt 0 ]; then
    print_success "ksqlDB procesando streams"
else
    print_warning "No hay streams activos en ksqlDB"
fi
echo ""

# Paso 6: Verificar detección de fraude
print_info "Paso 6: Verificando detección de fraude..."
fraud_high_value=$(docker exec fraud-kafka kafka-run-class kafka.tools.GetOffsetShell \
    --broker-list localhost:9092 \
    --topic fraud-high-value \
    --time -1 2>/dev/null | \
    awk -F ':' '{sum += $3} END {print sum}' || echo "0")

echo "    Alertas de alto valor: $fraud_high_value"

if [ "$fraud_high_value" -gt 0 ]; then
    print_success "Detección de fraude activa - $fraud_high_value alertas"
    
    # Mostrar muestra de alerta
    echo ""
    print_info "Muestra de alerta de fraude:"
    docker exec fraud-kafka kafka-console-consumer \
        --bootstrap-server localhost:9092 \
        --topic fraud-high-value \
        --from-beginning \
        --max-messages 1 \
        --timeout-ms 3000 2>/dev/null | \
        python3 -c "import sys, json; data=json.loads(sys.stdin.read()); print(f\"  Cuenta: {data.get('ACCOUNT_ID')}\"); print(f\"  Monto: \${data.get('AMOUNT')}\"); print(f\"  Razón: {data.get('REASON')}\"); print(f\"  Severidad: {data.get('SEVERITY')}\")" 2>/dev/null
else
    print_info "No se detectaron transacciones de alto valor (esperado si todas son < $10,000)"
fi
echo ""

# Paso 7: Verificar PostgreSQL
print_info "Paso 7: Verificando PostgreSQL..."
pg_count=$(docker exec fraud-postgres psql -U kafka_user -d fraud_detection -t -c "SELECT COUNT(*) FROM transactions;" 2>/dev/null | tr -d ' ' || echo "0")

echo "    Registros en PostgreSQL: $pg_count"

if [ "$pg_count" -gt 0 ]; then
    print_success "Datos persistidos en PostgreSQL"
else
    print_info "PostgreSQL vacío (el Sink Connector requiere configuración adicional)"
    print_info "Los datos están disponibles en Kafka y ksqlDB"
fi
echo ""

# Resumen Final
print_banner "Resumen de la Prueba"
echo ""

echo "Flujo de Datos:"
echo "  1. CSV generado: OK ($line_count líneas)"
echo "  2. CSV procesado: $([ "$processed_files" -gt 0 ] && echo "OK" || echo "PENDIENTE")"
echo "  3. Mensajes en Kafka: $([ "$transactions_count" -gt 0 ] && echo "OK ($transactions_count)" || echo "PENDIENTE")"
echo "  4. Streams de ksqlDB: $([ "$streams" -gt 0 ] && echo "OK ($streams streams)" || echo "PENDIENTE")"
echo "  5. Detección de fraude: $([ "$fraud_high_value" -gt 0 ] && echo "OK ($fraud_high_value alertas)" || echo "SIN ALERTAS")"
echo "  6. PostgreSQL: $([ "$pg_count" -gt 0 ] && echo "OK ($pg_count registros)" || echo "REQUIERE CONFIG")"
echo ""

# Determinar estado general
if [ "$transactions_count" -gt 0 ] && [ "$streams" -gt 0 ]; then
    print_success "PRUEBA EXITOSA - El pipeline está operacional"
    echo ""
    echo "Próximos pasos:"
    echo "  - Revisar alertas de fraude en los tópicos fraud-*"
    echo "  - Consultar estadísticas en ksqlDB"
    echo "  - Generar más datos: python3 generate_test_data.py -t 1000 -o data/input/batch2.csv"
elif [ "$transactions_count" -gt 0 ]; then
    print_warning "Pipeline parcialmente funcional"
    echo ""
    echo "Ejecuta los scripts de ksqlDB:"
    echo "  ./scripts/run-ksql-scripts.sh"
else
    print_warning "Pipeline requiere configuración"
    echo ""
    echo "Ejecuta el setup completo:"
    echo "  ./setup.sh"
fi

echo ""
exit 0


