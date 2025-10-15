#!/bin/bash
# Script para registrar schemas en Schema Registry
# Uso: ./register-schema.sh <schema-file> <subject-name>

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funciones
print_info() {
    echo -e "${BLUE}  $1${NC}"
}

print_success() {
    echo -e "${GREEN} $1${NC}"
}

print_error() {
    echo -e "${RED} $1${NC}"
}

# Cargar variables de entorno
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Configuración
SCHEMA_REGISTRY_URL="${SCHEMA_REGISTRY_URL:-http://localhost:8081}"
SCHEMA_FILE="${1}"
SUBJECT_NAME="${2}"

# Validar argumentos
if [ -z "$SCHEMA_FILE" ] || [ -z "$SUBJECT_NAME" ]; then
    echo "Uso: $0 <schema-file> <subject-name>"
    echo ""
    echo "Ejemplo:"
    echo "  $0 schemas/transaction-value-schema.json trx-fraud-transactions-value"
    echo ""
    exit 1
fi

# Validar que el archivo existe
if [ ! -f "$PROJECT_ROOT/$SCHEMA_FILE" ]; then
    print_error "Archivo no encontrado: $SCHEMA_FILE"
    exit 1
fi

echo ""
echo "=========================================="
echo "  Registro de Schema en Schema Registry"
echo "=========================================="
echo ""

print_info "Schema File: $SCHEMA_FILE"
print_info "Subject: $SUBJECT_NAME"
print_info "Schema Registry: $SCHEMA_REGISTRY_URL"
echo ""

# Leer y validar el schema JSON
print_info "Validando schema JSON..."
if ! cat "$PROJECT_ROOT/$SCHEMA_FILE" | jq '.' > /dev/null 2>&1; then
    print_error "El archivo no contiene JSON válido"
    exit 1
fi
print_success "Schema JSON válido"
echo ""

# Registrar el schema
print_info "Registrando schema en Schema Registry..."
response=$(curl -s -X POST \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data "{\"schemaType\":\"JSON\",\"schema\":$(cat "$PROJECT_ROOT/$SCHEMA_FILE" | jq -c tostring)}" \
    "$SCHEMA_REGISTRY_URL/subjects/$SUBJECT_NAME/versions")

# Verificar respuesta
if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
    schema_id=$(echo "$response" | jq -r '.id')
    print_success "Schema registrado exitosamente"
    echo "    Schema ID: $schema_id"
else
    print_error "Error al registrar schema"
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
    exit 1
fi

echo ""

# Verificar el schema registrado
print_info "Verificando schema registrado..."
latest=$(curl -s "$SCHEMA_REGISTRY_URL/subjects/$SUBJECT_NAME/versions/latest")

if echo "$latest" | jq -e '.version' > /dev/null 2>&1; then
    version=$(echo "$latest" | jq -r '.version')
    id=$(echo "$latest" | jq -r '.id')
    schema_type=$(echo "$latest" | jq -r '.schemaType')
    
    print_success "Schema verificado"
    echo "    Subject: $SUBJECT_NAME"
    echo "    Version: $version"
    echo "    ID: $id"
    echo "    Type: $schema_type"
else
    print_error "No se pudo verificar el schema"
fi

echo ""
print_success "Proceso completado"
echo ""

exit 0

