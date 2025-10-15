#!/bin/bash
# =====================================================
# Script: create-env.sh
# Crea el archivo .env desde el template
# =====================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

clear

print_banner "Configuración de Variables de Entorno"

echo ""

# Verificar si env.template existe
if [ ! -f "env.template" ]; then
    print_error "Archivo env.template no encontrado"
    exit 1
fi

# Verificar si .env ya existe
if [ -f ".env" ]; then
    echo ""
    print_warning "El archivo .env ya existe"
    echo ""
    read -p "¿Deseas sobrescribirlo? (s/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        print_info "Operación cancelada. El archivo .env no fue modificado."
        exit 0
    fi
    
    # Hacer backup del .env existente
    backup_name=".env.backup.$(date +%Y%m%d_%H%M%S)"
    cp .env "$backup_name"
    print_success "Backup creado: $backup_name"
fi

echo ""

# Copiar el template
cp env.template .env
print_success "Archivo .env creado desde env.template"

echo ""

# Preguntar si quiere personalizar
print_info "El archivo .env ha sido creado con valores por defecto."
echo ""
echo "Configuraciones importantes que puedes querer cambiar:"
echo ""
echo "  1. POSTGRES_PASSWORD=kafka_pass"
echo "     Contraseña de PostgreSQL (cambiar en producción)"
echo ""
echo "  2. KAFKA_HEAP_OPTS=-Xmx1G -Xms1G"
echo "     Memoria asignada a Kafka (ajustar según recursos)"
echo ""
echo "  3. ENVIRONMENT=development"
echo "     Entorno de ejecución"
echo ""

read -p "¿Deseas editar el archivo .env ahora? (s/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Ss]$ ]]; then
    # Detectar editor disponible
    if command -v nano &> /dev/null; then
        nano .env
    elif command -v vi &> /dev/null; then
        vi .env
    elif command -v vim &> /dev/null; then
        vim .env
    else
        print_warning "No se encontró un editor de texto. Edita .env manualmente."
    fi
fi

echo ""
print_banner "Configuración Completada"

echo ""
print_info "El archivo .env está listo para usar"
echo ""
echo "Próximos pasos:"
echo ""
echo "  1. Revisar/editar .env si es necesario:"
echo "     nano .env"
echo ""
echo "  2. Iniciar los servicios Docker:"
echo "     docker-compose up -d"
echo ""
echo "  3. Ejecutar el setup:"
echo "     ./setup.sh"
echo ""
echo "  4. Generar datos de prueba:"
echo "     python generate_test_data.py -t 1000 -o data/input/transactions.csv"
echo ""

print_success "¡Listo para comenzar!"
echo ""

exit 0

