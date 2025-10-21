#!/bin/bash
# =====================================================
# Script Principal de Setup
# Sistema de Detección de Fraude con Apache Kafka
# =====================================================

set -e

# Cargar variables de entorno
if [ -f .env ]; then
    echo " Cargando variables de entorno desde .env..."
    set -a
    source .env
    set +a
else
    echo "  Archivo .env no encontrado. Usando valores por defecto."
    echo " Crea un archivo .env desde env.template: cp env.template .env"
fi

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración (con valores por defecto si no están en .env)
KAFKA_BROKER="${KAFKA_BROKER:-localhost:9092}"
TRANSACTIONS_TOPIC="${TRANSACTIONS_TOPIC:-trx-fraud-transactions}"
FRAUD_ALERTS_TOPIC="${FRAUD_ALERTS_TOPIC:-fraud-alerts}"
# Topics de detección de fraude
FRAUD_HIGH_VALUE_TOPIC="${FRAUD_HIGH_VALUE_TOPIC:-fraud-high-value}"
FRAUD_HIGH_FREQUENCY_TOPIC="${FRAUD_HIGH_FREQUENCY_TOPIC:-fraud-high-frequency-table}"
FRAUD_MULTIPLE_LOCATIONS_TOPIC="${FRAUD_MULTIPLE_LOCATIONS_TOPIC:-fraud-multiple-locations-table}"
FRAUD_UNUSUAL_TIME_TOPIC="${FRAUD_UNUSUAL_TIME_TOPIC:-fraud-unusual-time}"
TOPICS=("$TRANSACTIONS_TOPIC" "$FRAUD_ALERTS_TOPIC" "$FRAUD_HIGH_VALUE_TOPIC" "$FRAUD_HIGH_FREQUENCY_TOPIC" "$FRAUD_MULTIPLE_LOCATIONS_TOPIC" "$FRAUD_UNUSUAL_TIME_TOPIC")
PARTITIONS="${TOPIC_PARTITIONS:-3}"
REPLICATION_FACTOR="${TOPIC_REPLICATION_FACTOR:-1}"

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

# Función para verificar si Docker está corriendo
check_docker() {
    print_step "Verificando Docker..."
    
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker no está corriendo. Por favor inicia Docker Desktop."
        exit 1
    fi
    
    print_success "Docker está corriendo"
}

# Función para verificar si Docker Compose está instalado
check_docker_compose() {
    print_step "Verificando Docker Compose..."
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose no está instalado"
        exit 1
    fi
    
    local version=$(docker-compose --version)
    print_success "Docker Compose está instalado: $version"
}

# Función para crear tópicos de Kafka
create_kafka_topics() {
    print_step "Creando tópicos de Kafka..."
    
    for topic in "${TOPICS[@]}"; do
        print_info "Creando tópico: $topic"
        
        # Verificar si el tópico existe
        local topic_exists=$(docker exec fraud-kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null | grep -c "^${topic}$" || true)
        
        if [ "$topic_exists" -eq 0 ]; then
            docker exec fraud-kafka kafka-topics --create \
                --bootstrap-server localhost:9092 \
                --topic "$topic" \
                --partitions $PARTITIONS \
                --replication-factor $REPLICATION_FACTOR \
                --if-not-exists > /dev/null 2>&1
            
            print_success "Tópico creado: $topic"
        else
            print_warning "Tópico ya existe: $topic"
        fi
    done
}

# Función para listar tópicos
list_topics() {
    print_step "Tópicos de Kafka disponibles:"
    docker exec fraud-kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null
}

# Función para verificar el estado de PostgreSQL
check_postgres() {
    print_step "Verificando PostgreSQL..."
    
    local max_retries=30
    local retries=0
    
    while [ $retries -lt $max_retries ]; do
        if docker exec fraud-postgres pg_isready -U kafka_user -d fraud_detection > /dev/null 2>&1; then
            print_success "PostgreSQL está listo"
            return 0
        fi
        
        retries=$((retries + 1))
        sleep 2
    done
    
    print_error "PostgreSQL no está disponible"
    return 1
}

# Función para mostrar el estado del sistema
show_system_status() {
    print_banner "Estado del Sistema"
    
    print_info "Servicios Docker:"
    docker-compose ps
    
    echo ""
    print_info "Tópicos de Kafka:"
    list_topics
    
    echo ""
    print_info "Conectores de Kafka Connect:"
    curl -sf http://localhost:8083/connectors 2>/dev/null | python3 -m json.tool || echo "[]"
    
    echo ""
    print_info "Tablas en PostgreSQL:"
    docker exec fraud-postgres psql -U kafka_user -d fraud_detection -c "\dt" 2>/dev/null || echo "No hay tablas"
}

# Función para generar datos de prueba
generate_test_data() {
    print_step "Generando datos de prueba..."
    
    if [ -f "generate_test_data.py" ]; then
        python3 generate_test_data.py --transactions 1000 --fraud-rate 0.05 --output data/input/transactions_001.csv
        print_success "Datos de prueba generados"
    else
        print_warning "Script de generación de datos no encontrado"
    fi
}

# Función para mostrar URLs útiles
show_useful_urls() {
    print_banner "URLs Útiles"
    
    echo "   Adminer (PostgreSQL UI):     http://localhost:8080"
    echo "   Kafka Connect API:           http://localhost:8083"
    echo "   Schema Registry:             http://localhost:8081"
    echo "   ksqlDB Server:               http://localhost:8088"
    echo ""
    echo "   Credenciales PostgreSQL:"
    echo "     Server:   postgres"
    echo "     Database: fraud_detection"
    echo "     Username: kafka_user"
    echo "     Password: kafka_pass"
    echo ""
}

# Función para mostrar comandos útiles
show_useful_commands() {
    print_banner "Comandos Útiles"
    
    echo "  # Ver logs de un servicio:"
    echo "  docker-compose logs -f [service_name]"
    echo ""
    echo "  # Conectar a ksqlDB CLI:"
    echo "  docker exec -it ksqldb-cli ksql http://ksqldb-server:8088"
    echo ""
    echo "  # Ver tópicos de Kafka:"
    echo "  docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list"
    echo ""
    echo "  # Consumir mensajes de un tópico:"
    echo "  docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic trx-fraud-transactions --from-beginning"
    echo ""
    echo "  # Verificar conectores:"
    echo "  curl http://localhost:8083/connectors"
    echo ""
    echo "  # Generar más datos de prueba:"
    echo "  python3 generate_test_data.py --transactions 5000 --fraud-rate 0.08 --output data/input/transactions_002.csv"
    echo ""
}

# Función para levantar servicios Docker
start_docker_services() {
    print_step "Levantando servicios Docker..."
    
    if docker-compose up -d; then
        print_success "Servicios Docker iniciados"
        return 0
    else
        print_error "Error al iniciar servicios Docker"
        return 1
    fi
}

# Función para registrar schemas
register_schemas() {
    print_step "Registrando schemas en Schema Registry..."
    
    if [ -f "scripts/register-schema.sh" ] && [ -f "schemas/transaction-value-schema.json" ]; then
        if ./scripts/register-schema.sh schemas/transaction-value-schema.json trx-fraud-transactions-value; then
            print_success "Schema registrado correctamente"
            return 0
        else
            print_warning "Advertencia al registrar schema (puede ser normal)"
            return 0
        fi
    else
        print_warning "Script de registro de schema o archivo de schema no encontrado"
        return 0
    fi
}

# Función principal
main() {    
    print_banner "Sistema de Detección de Fraude - Setup Completo"
    echo ""
    
    # Verificar prerequisitos
    check_docker
    check_docker_compose
    
    echo ""
    
    # Paso 1: Levantar servicios Docker
    print_step "Paso 1: Levantando servicios Docker..."
    start_docker_services || exit 1
    
    echo ""
    
    # Paso 2: Esperar a que los servicios estén listos
    print_step "Paso 2: Esperando a que todos los servicios estén listos..."
    if [ -f "scripts/wait-for-services.sh" ]; then
        ./scripts/wait-for-services.sh
    else
        print_warning "Script wait-for-services.sh no encontrado, esperando 90 segundos..."
        sleep 90
    fi
    
    echo ""
    
    # Paso 3: Registrar schemas
    print_step "Paso 3: Registrando schemas..."
    register_schemas
    
    echo ""
    
    # Paso 4: Crear tópicos (si es necesario)
    print_step "Paso 4: Verificando tópicos de Kafka..."
    create_kafka_topics
    
    echo ""
    
    # Paso 5: Verificar PostgreSQL
    check_postgres
    
    echo ""
    
    # Paso 6: Desplegar conectores
    print_step "Paso 6: Desplegando conectores..."
    if [ -f "scripts/deploy-connectors.sh" ]; then
        ./scripts/deploy-connectors.sh
    else
        print_error "Script deploy-connectors.sh no encontrado"
    fi
    
    echo ""
    
    # Paso 7: Ejecutar scripts de ksqlDB
    print_step "Paso 7: Ejecutando scripts de ksqlDB..."
    if [ -f "scripts/run-ksql-scripts.sh" ]; then
        ./scripts/run-ksql-scripts.sh
    else
        print_error "Script run-ksql-scripts.sh no encontrado"
    fi
    
    echo ""
    
    # Paso 8: Mostrar estado del sistema
    show_system_status
    
    echo ""
    
    # Mostrar URLs útiles
    show_useful_urls
    
    # Mostrar comandos útiles
    show_useful_commands
    
    # Mensaje final
    print_banner "Setup Completado Exitosamente"
    print_success "El sistema está completamente configurado y listo para usar"
    echo ""
    print_info "Para ejecutar una demostración completa del pipeline, ejecuta:"
    echo ""
    echo "  ${GREEN}./demo.sh${NC}"
    echo ""
    print_info "El script de demo generará datos de prueba y validará todo el flujo."
    echo ""
}

# Manejo de señales
trap 'echo ""; print_warning "Setup interrumpido por el usuario"; exit 130' INT TERM

# Ejecutar función principal
main "$@"

exit 0

