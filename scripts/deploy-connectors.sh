#!/bin/bash
# =====================================================
# Script: deploy-connectors.sh
# Despliega los conectores de Kafka Connect
# =====================================================

set -e

# Cargar variables de entorno desde el directorio raíz del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    echo " Cargando variables de entorno desde .env..."
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración (con valores por defecto)
CONNECT_URL="${KAFKA_CONNECT_URL:-http://localhost:8083}"
MAX_RETRIES="${MAX_RETRIES:-30}"
RETRY_INTERVAL="${RETRY_INTERVAL:-2}"

# Función para imprimir mensajes con color
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

# Función para esperar a que Kafka Connect esté listo
wait_for_connect() {
    print_info "Esperando a que Kafka Connect esté listo..."
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -sf "$CONNECT_URL" > /dev/null 2>&1; then
            print_success "Kafka Connect está listo"
            return 0
        fi
        
        retries=$((retries + 1))
        echo -n "."
        sleep $RETRY_INTERVAL
    done
    
    print_error "Kafka Connect no está disponible"
    return 1
}

# Función para verificar si un conector existe
connector_exists() {
    local connector_name=$1
    curl -sf "$CONNECT_URL/connectors/$connector_name" > /dev/null 2>&1
}

# Función para eliminar un conector si existe
delete_connector() {
    local connector_name=$1
    
    if connector_exists "$connector_name"; then
        print_info "Eliminando conector existente: $connector_name"
        curl -sf -X DELETE "$CONNECT_URL/connectors/$connector_name" > /dev/null
        sleep 2
        print_success "Conector eliminado: $connector_name"
    fi
}

# Función para desplegar un conector
deploy_connector() {
    local connector_file=$1
    local connector_name=$2
    
    print_info "Desplegando conector: $connector_name"
    
    # Eliminar si existe
    delete_connector "$connector_name"
    
    # Desplegar conector
    local response=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        --data @"$connector_file" \
        "$CONNECT_URL/connectors")
    
    if [ $? -eq 0 ]; then
        print_success "Conector desplegado: $connector_name"
        return 0
    else
        print_error "Error al desplegar conector: $connector_name"
        return 1
    fi
}

# Función para verificar el estado de un conector
check_connector_status() {
    local connector_name=$1
    
    print_info "Verificando estado del conector: $connector_name"
    
    local status=$(curl -sf "$CONNECT_URL/connectors/$connector_name/status")
    
    if [ $? -eq 0 ]; then
        local connector_state=$(echo "$status" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['connector']['state'])" 2>/dev/null || echo "UNKNOWN")
        local task_state=$(echo "$status" | python3 -c "import sys, json; data=json.load(sys.stdin); tasks=data.get('tasks',[]); print(tasks[0]['state'] if tasks else 'NO_TASKS')" 2>/dev/null || echo "UNKNOWN")
        
        if [ "$connector_state" = "RUNNING" ] && [ "$task_state" = "RUNNING" ]; then
            print_success "Conector $connector_name - Connector: $connector_state, Task: $task_state"
        elif [ "$connector_state" = "RUNNING" ] && [ "$task_state" = "FAILED" ]; then
            print_warning "Conector $connector_name - Connector: $connector_state, Task: $task_state (revisar logs)"
            echo "    Comando para ver logs: docker logs fraud-kafka-connect 2>&1 | grep $connector_name | tail -20"
        else
            print_warning "Conector $connector_name - Connector: $connector_state, Task: $task_state"
        fi
    else
        print_error "No se pudo obtener el estado del conector: $connector_name"
    fi
}

# Función para listar todos los conectores
list_connectors() {
    print_info "Conectores desplegados:"
    local connectors=$(curl -sf "$CONNECT_URL/connectors")
    echo "$connectors" | python3 -m json.tool 2>/dev/null || echo "$connectors"
}

# Banner
echo ""
echo "=========================================="
echo "  Despliegue de Conectores"
echo "=========================================="
echo ""

# Esperar a que Kafka Connect esté listo
wait_for_connect || exit 1

echo ""

# Desplegar CSV Source Connector
if [ -f "connectors/csv-source-connector.json" ]; then
    deploy_connector "connectors/csv-source-connector.json" "csv-source-connector"
    sleep 8
    check_connector_status "csv-source-connector"
    
    # Si el conector está FAILED (esperando archivos), intentar reiniciarlo después de unos segundos
    csv_state=$(curl -sf "$CONNECT_URL/connectors/csv-source-connector/status" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['connector']['state'])" 2>/dev/null || echo "UNKNOWN")
    if [ "$csv_state" = "FAILED" ]; then
        print_info "El conector está esperando archivos CSV. Se reiniciará automáticamente cuando detecte archivos."
    fi
else
    print_error "Archivo no encontrado: connectors/csv-source-connector.json"
fi

echo ""

# Desplegar PostgreSQL Sink Connector
if [ -f "connectors/postgres-sink-connector.json" ]; then
    deploy_connector "connectors/postgres-sink-connector.json" "postgres-sink-connector"
    sleep 8
    check_connector_status "postgres-sink-connector"
    
    # Verificar que el sink está usando schemas
    print_info "Verificando configuración de schemas..."
    sink_config=$(curl -sf "$CONNECT_URL/connectors/postgres-sink-connector/config" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('value.converter.schemas.enable', 'false'))" 2>/dev/null || echo "unknown")
    if [ "$sink_config" = "true" ]; then
        print_success "Sink Connector configurado con schemas habilitados"
    else
        print_warning "Sink Connector puede no estar usando schemas correctamente"
    fi
else
    print_error "Archivo no encontrado: connectors/postgres-sink-connector.json"
fi

echo ""

# Desplegar Fraud Alerts Sink Connector
if [ -f "connectors/fraud-alerts-sink-connector.json" ]; then
    deploy_connector "connectors/fraud-alerts-sink-connector.json" "fraud-alerts-sink-connector"
    sleep 8
    check_connector_status "fraud-alerts-sink-connector"
else
    print_warning "Archivo no encontrado: connectors/fraud-alerts-sink-connector.json"
fi

echo ""

# Listar todos los conectores
list_connectors

echo ""
print_success "Despliegue de conectores completado"
echo ""

# Mostrar cómo verificar los conectores
print_info "Para verificar los conectores manualmente:"
echo "  curl http://localhost:8083/connectors"
echo "  curl http://localhost:8083/connectors/csv-source-connector/status"
echo "  curl http://localhost:8083/connectors/postgres-sink-connector/status"
echo ""

exit 0

