#!/bin/bash
# =====================================================
# Script: run-ksql-scripts.sh
# Ejecuta los scripts de ksqlDB en orden
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
KSQL_URL="${KSQLDB_SERVER_URL:-http://localhost:8088}"
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

# Función para esperar a que ksqlDB esté listo
wait_for_ksql() {
    print_info "Esperando a que ksqlDB esté listo..."
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -sf "$KSQL_URL/info" > /dev/null 2>&1; then
            print_success "ksqlDB está listo"
            return 0
        fi
        
        retries=$((retries + 1))
        echo -n "."
        sleep $RETRY_INTERVAL
    done
    
    print_error "ksqlDB no está disponible"
    return 1
}

# Función para ejecutar un archivo SQL de ksqlDB
run_ksql_file() {
    local sql_file=$1
    local file_name=$(basename "$sql_file")
    
    print_info "Ejecutando script: $file_name"
    
    if [ ! -f "$sql_file" ]; then
        print_error "Archivo no encontrado: $sql_file"
        return 1
    fi
    
    # Leer el contenido del archivo y preparar la consulta
    local sql_content=$(cat "$sql_file")
    
    # Separar statements por punto y coma
    IFS=';' read -ra STATEMENTS <<< "$sql_content"
    
    local success=0
    local failed=0
    
    for statement in "${STATEMENTS[@]}"; do
        # Limpiar el statement
        statement=$(echo "$statement" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Saltar statements vacíos o comentarios
        if [ -z "$statement" ] || [[ "$statement" =~ ^--.*$ ]]; then
            continue
        fi
        
        # Ejecutar el statement
        local payload="{\"ksql\":\"$statement;\", \"streamsProperties\":{}}"
        local response=$(curl -sf -X POST "$KSQL_URL/ksql" \
            -H "Content-Type: application/vnd.ksql.v1+json" \
            -d "$payload" 2>&1)
        
        if [ $? -eq 0 ]; then
            # Verificar si hay error en la respuesta
            if echo "$response" | grep -q '"error_code"'; then
                print_warning "Advertencia en statement (puede ser normal si ya existe)"
                failed=$((failed + 1))
            else
                success=$((success + 1))
            fi
        else
            print_warning "Error ejecutando statement"
            failed=$((failed + 1))
        fi
    done
    
    print_success "Script completado: $file_name (Éxitos: $success, Advertencias: $failed)"
    return 0
}

# Función alternativa: ejecutar scripts usando docker exec
run_ksql_file_docker() {
    local sql_file=$1
    local file_name=$(basename "$sql_file")
    
    print_info "Ejecutando script (vía Docker): $file_name"
    
    if [ ! -f "$sql_file" ]; then
        print_error "Archivo no encontrado: $sql_file"
        return 1
    fi
    
    # Ejecutar usando ksqldb-cli
    docker exec -i fraud-ksqldb-cli ksql http://fraud-ksqldb-server:8088 < "$sql_file" > /tmp/ksql_output.log 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Script ejecutado: $file_name"
        # Mostrar un resumen del output
        grep -i "created\|message" /tmp/ksql_output.log | head -5 2>/dev/null
        return 0
    else
        print_warning "Advertencia al ejecutar script: $file_name (puede ser normal si ya existe)"
        return 0
    fi
}

# Función para verificar streams y tablas creados
verify_ksql_objects() {
    print_info "Verificando streams y tablas creados..."
    
    # Listar streams
    local streams=$(curl -sf -X POST "$KSQL_URL/ksql" \
        -H "Content-Type: application/vnd.ksql.v1+json" \
        -d '{"ksql":"LIST STREAMS;", "streamsProperties":{}}')
    
    if [ $? -eq 0 ]; then
        print_success "Streams disponibles:"
        echo "$streams" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | while read stream; do
            echo "  - $stream"
        done
    fi
    
    # Listar tablas
    local tables=$(curl -sf -X POST "$KSQL_URL/ksql" \
        -H "Content-Type: application/vnd.ksql.v1+json" \
        -d '{"ksql":"LIST TABLES;", "streamsProperties":{}}')
    
    if [ $? -eq 0 ]; then
        print_success "Tables disponibles:"
        echo "$tables" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | while read table; do
            echo "  - $table"
        done
    fi
}

# Banner
echo ""
echo "=========================================="
echo "  Ejecución de Scripts ksqlDB"
echo "=========================================="
echo ""

# Esperar a que ksqlDB esté listo
wait_for_ksql || exit 1

echo ""

# Ejecutar scripts en orden
print_info "Ejecutando scripts de ksqlDB en orden..."
echo ""

if [ -f "ksqldb/01-create-streams.sql" ]; then
    run_ksql_file_docker "ksqldb/01-create-streams.sql"
    sleep 3
else
    print_error "Archivo no encontrado: ksqldb/01-create-streams.sql"
fi

echo ""

if [ -f "ksqldb/02-fraud-detection.sql" ]; then
    run_ksql_file_docker "ksqldb/02-fraud-detection.sql"
    sleep 3
else
    print_error "Archivo no encontrado: ksqldb/02-fraud-detection.sql"
fi

echo ""

if [ -f "ksqldb/03-aggregations.sql" ]; then
    run_ksql_file_docker "ksqldb/03-aggregations.sql"
    sleep 3
else
    print_error "Archivo no encontrado: ksqldb/03-aggregations.sql"
fi

echo ""

# Verificar objetos creados
verify_ksql_objects

echo ""
print_success "Ejecución de scripts ksqlDB completada"
echo ""

# Mostrar cómo interactuar con ksqlDB
print_info "Para interactuar con ksqlDB manualmente:"
echo "  docker exec -it ksqldb-cli ksql http://ksqldb-server:8088"
echo ""
echo "Consultas útiles:"
echo "  SHOW STREAMS;"
echo "  SHOW TABLES;"
echo "  SELECT * FROM transactions_stream EMIT CHANGES LIMIT 10;"
echo "  SELECT * FROM fraud_alerts_consolidated EMIT CHANGES;"
echo ""

exit 0

