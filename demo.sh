#!/bin/bash
# =====================================================
# Script de Demo del Pipeline de Detección de Fraude
# Ejecuta una demostración completa del sistema
# =====================================================

set -e

# Cargar variables de entorno
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con color
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

print_step() {
    echo -e "${MAGENTA} $1${NC}"
}

# Función para verificar si un servicio está corriendo
check_service() {
    local service_name=$1
    local check_command=$2
    
    if eval "$check_command" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Función para verificar el estado del sistema
check_system_status() {
    local errors=0
    
    print_step "Verificando estado del sistema..."
    echo ""
    
    # Verificar Docker Compose
    if ! docker-compose ps | grep -q "Up"; then
        print_error "Los servicios Docker no están corriendo"
        errors=$((errors + 1))
    else
        print_success "Servicios Docker: Corriendo"
    fi
    
    # Verificar Kafka
    if ! check_service "Kafka" "docker exec fraud-kafka kafka-topics --bootstrap-server localhost:9092 --list"; then
        print_error "Kafka no está disponible"
        errors=$((errors + 1))
    else
        print_success "Kafka: Disponible"
    fi
    
    # Verificar Kafka Connect
    if ! check_service "Kafka Connect" "curl -sf http://localhost:8083"; then
        print_error "Kafka Connect no está disponible"
        errors=$((errors + 1))
    else
        print_success "Kafka Connect: Disponible"
        
        # Verificar conectores
        local connectors=$(curl -sf http://localhost:8083/connectors 2>/dev/null | grep -o "csv-source-connector" | wc -l)
        if [ "$connectors" -eq 0 ]; then
            print_error "Conectores no están desplegados"
            errors=$((errors + 1))
        else
            print_success "Conectores: Desplegados"
        fi
    fi
    
    # Verificar ksqlDB
    if ! check_service "ksqlDB" "curl -sf http://localhost:8088/info"; then
        print_error "ksqlDB Server no está disponible"
        errors=$((errors + 1))
    else
        print_success "ksqlDB Server: Disponible"
        
        # Verificar streams
        local streams=$(curl -sf -X POST http://localhost:8088/ksql \
            -H "Content-Type: application/vnd.ksql.v1+json" \
            -d '{"ksql":"SHOW STREAMS;","streamsProperties":{}}' 2>/dev/null | \
            grep -o "TRANSACTIONS_STREAM" | wc -l)
        
        if [ "$streams" -eq 0 ]; then
            print_error "Streams de ksqlDB no están creados"
            errors=$((errors + 1))
        else
            print_success "Streams de ksqlDB: Creados"
        fi
    fi
    
    # Verificar PostgreSQL
    if ! check_service "PostgreSQL" "docker exec fraud-postgres pg_isready -U kafka_user"; then
        print_error "PostgreSQL no está disponible"
        errors=$((errors + 1))
    else
        print_success "PostgreSQL: Disponible"
    fi
    
    echo ""
    
    if [ $errors -gt 0 ]; then
        print_error "Se encontraron $errors problemas en el sistema"
        return 1
    else
        print_success "Sistema completamente configurado y operacional"
        return 0
    fi
}

# Función para mostrar estadísticas del sistema
show_statistics() {
    local topic=$1
    local label=$2
    
    local count=$(docker exec fraud-kafka kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list localhost:9092 \
        --topic "$topic" \
        --time -1 2>/dev/null | \
        awk -F ':' '{sum += $3} END {print sum}')
    
    echo "    $label: ${count:-0}"
}

# Función para ejecutar la demo
run_demo() {
    print_banner "Demostración del Pipeline de Detección de Fraude"
    echo ""
    
    # Paso 1: Generar datos de prueba
    print_step "Paso 1: Generando datos de prueba con casos específicos de fraude..."
    echo ""
    
    if [ -f "generate_fraud_test_data.py" ]; then
        python3 generate_fraud_test_data.py
        echo ""
        print_success "Datos de prueba generados exitosamente"
    else
        print_error "Script de generación de datos no encontrado"
        return 1
    fi
    
    echo ""
    
    # Paso 2: Esperar procesamiento
    print_step "Paso 2: Esperando procesamiento del pipeline..."
    echo ""
    print_info "Procesando datos (esto tomará aproximadamente 25 segundos)..."
    
    for i in {1..25}; do
        echo -n "."
        sleep 1
    done
    echo ""
    echo ""
    print_success "Procesamiento completado"
    
    echo ""
    
    # Paso 3: Mostrar resultados
    print_step "Paso 3: Resultados del Pipeline"
    echo ""
    
    # Archivos procesados
    print_info "Archivos CSV procesados:"
    local processed=$(docker exec fraud-kafka-connect find /data/processed -name "*.csv" -type f 2>/dev/null | wc -l)
    echo "    Total: $processed archivo(s)"
    echo ""
    
    # Mensajes en Kafka
    print_info "Mensajes en Kafka Topics:"
    show_statistics "trx-fraud-transactions" "Transacciones"
    show_statistics "fraud-high-value" "Alertas de Alto Valor"
    show_statistics "fraud-unusual-time" "Alertas de Horario Inusual"
    echo ""
    
    # Streams y Tablas
    print_info "Objetos de ksqlDB:"
    local streams=$(curl -sf -X POST http://localhost:8088/ksql \
        -H "Content-Type: application/vnd.ksql.v1+json" \
        -d '{"ksql":"SHOW STREAMS;","streamsProperties":{}}' 2>/dev/null | \
        grep -o '"name"' | wc -l)
    echo "    Streams: $streams"
    
    local tables=$(curl -sf -X POST http://localhost:8088/ksql \
        -H "Content-Type: application/vnd.ksql.v1+json" \
        -d '{"ksql":"SHOW TABLES;","streamsProperties":{}}' 2>/dev/null | \
        grep -o '"name"' | wc -l)
    echo "    Tablas: $tables"
    echo ""
    
    # Datos en PostgreSQL
    print_info "Datos en PostgreSQL:"
    local pg_transactions=$(docker exec fraud-postgres psql -U kafka_user -d fraud_detection -t -c "SELECT COUNT(*) FROM transactions;" 2>/dev/null | tr -d ' ' || echo "0")
    local pg_alerts=$(docker exec fraud-postgres psql -U kafka_user -d fraud_detection -t -c "SELECT COUNT(*) FROM fraud_alerts;" 2>/dev/null | tr -d ' ' || echo "0")
    echo "    Transacciones: $pg_transactions"
    echo "    Alertas de Fraude: $pg_alerts"
    echo ""
    
    # Paso 4: Mostrar ejemplo de alerta
    print_step "Paso 4: Ejemplo de Alerta de Fraude"
    echo ""
    
    print_info "Muestra de alerta de alto valor detectada:"
    docker exec fraud-kafka kafka-console-consumer \
        --bootstrap-server localhost:9092 \
        --topic fraud-high-value \
        --from-beginning \
        --max-messages 1 \
        --timeout-ms 3000 2>/dev/null | \
        python3 -c "
import sys, json
try:
    data = json.loads(sys.stdin.read())
    print(f'  ID Transacción: {data.get(\"TRANSACTION_ID\", \"N/A\")}')
    print(f'  Cuenta: {data.get(\"ACCOUNT_ID\", \"N/A\")}')
    print(f'  Monto: \${data.get(\"AMOUNT\", 0):,.2f}')
    print(f'  Tipo de Fraude: {data.get(\"FRAUD_TYPE\", \"N/A\")}')
    print(f'  Severidad: {data.get(\"SEVERITY\", \"N/A\")}')
    print(f'  Razón: {data.get(\"REASON\", \"N/A\")}')
except:
    print('  No se pudo leer la alerta')
" 2>/dev/null || print_warning "No hay alertas disponibles aún"
    
    echo ""
    
    # Paso 5: Consulta en PostgreSQL
    print_step "Paso 5: Consulta de Alertas en PostgreSQL"
    echo ""
    
    print_info "Resumen de alertas por tipo de fraude:"
    docker exec fraud-postgres psql -U kafka_user -d fraud_detection -t -c "
        SELECT 
            fraud_type,
            severity,
            COUNT(*) as total
        FROM fraud_alerts
        GROUP BY fraud_type, severity
        ORDER BY total DESC;
    " 2>/dev/null || print_warning "No hay datos en PostgreSQL aún"
    
    echo ""
    
    # Mensaje final
    print_banner "Demo Completada"
    print_success "La demostración del pipeline se ejecutó exitosamente"
    echo ""
    print_info "Puedes explorar los datos usando:"
    echo ""
    echo "  # Consultar PostgreSQL:"
    echo "  docker exec -it fraud-postgres psql -U kafka_user -d fraud_detection"
    echo ""
    echo "  # Consultar ksqlDB:"
    echo "  docker exec -it fraud-ksqldb-cli ksql http://fraud-ksqldb-server:8088"
    echo ""
    echo "  # Interfaz web de Adminer (PostgreSQL):"
    echo "  http://localhost:8080"
    echo ""
    print_info "Para validar el flujo completo de datos:"
    echo ""
    echo "  ./scripts/validate-data-flow.sh"
    echo ""
}

# Función principal
main() {
    echo ""
    print_banner "Demo del Sistema de Detección de Fraude"
    echo ""
    
    # Verificar estado del sistema
    if ! check_system_status; then
        echo ""
        print_banner "Sistema No Configurado"
        print_error "El pipeline no está configurado o no está funcionando correctamente"
        echo ""
        print_info "Por favor, ejecuta el script de configuración primero:"
        echo ""
        echo "  ${GREEN}./setup.sh${NC}"
        echo ""
        print_info "Una vez completada la configuración, vuelve a ejecutar:"
        echo ""
        echo "  ${GREEN}./demo.sh${NC}"
        echo ""
        exit 1
    fi
    
    echo ""
    
    # Ejecutar demo
    run_demo
}

# Manejo de señales
trap 'echo ""; print_warning "Demo interrumpida por el usuario"; exit 130' INT TERM

# Ejecutar función principal
main "$@"

exit 0

