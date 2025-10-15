#!/bin/bash
# =====================================================
# Script: wait-for-services.sh
# Espera a que todos los servicios estén listos
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
MAX_RETRIES="${MAX_RETRIES:-60}"
RETRY_INTERVAL="${RETRY_INTERVAL:-5}"

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

# Función para esperar a que un servicio esté disponible
wait_for_service() {
    local service_name=$1
    local host=$2
    local port=$3
    local retries=0
    
    print_info "Esperando a que $service_name esté disponible en $host:$port..."
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if nc -z $host $port 2>/dev/null; then
            print_success "$service_name está disponible"
            return 0
        fi
        
        retries=$((retries + 1))
        echo -n "."
        sleep $RETRY_INTERVAL
    done
    
    print_error "$service_name no está disponible después de $((MAX_RETRIES * RETRY_INTERVAL)) segundos"
    return 1
}

# Función para verificar endpoint HTTP
wait_for_http() {
    local service_name=$1
    local url=$2
    local retries=0
    
    print_info "Esperando a que $service_name responda en $url..."
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            print_success "$service_name está respondiendo"
            return 0
        fi
        
        retries=$((retries + 1))
        echo -n "."
        sleep $RETRY_INTERVAL
    done
    
    print_error "$service_name no está respondiendo después de $((MAX_RETRIES * RETRY_INTERVAL)) segundos"
    return 1
}

# Banner
echo ""
echo "=========================================="
echo "  Verificación de Servicios"
echo "=========================================="
echo ""

# Verificar servicios
wait_for_service "Zookeeper" "localhost" "2181" || exit 1
wait_for_service "Kafka" "localhost" "9092" || exit 1
wait_for_http "Schema Registry" "http://localhost:8081" || exit 1
wait_for_http "Kafka Connect" "http://localhost:8083" || exit 1
wait_for_http "ksqlDB Server" "http://localhost:8088/info" || exit 1
wait_for_service "PostgreSQL" "localhost" "5432" || exit 1

echo ""
print_success "Todos los servicios están disponibles y listos"
echo ""

# Verificación adicional de Kafka Connect plugins
print_info "Verificando plugins de Kafka Connect..."
if curl -sf http://localhost:8083/connector-plugins | grep -q "SpoolDirCsvSourceConnector"; then
    print_success "Plugin CSV Source Connector encontrado"
else
    print_warning "Plugin CSV Source Connector no encontrado"
fi

if curl -sf http://localhost:8083/connector-plugins | grep -q "JdbcSinkConnector"; then
    print_success "Plugin JDBC Sink Connector encontrado"
else
    print_warning "Plugin JDBC Sink Connector no encontrado"
fi

echo ""
print_success "Verificación de servicios completada"
echo ""

exit 0

