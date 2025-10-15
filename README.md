# Sistema de Detección de Fraude en Transacciones Financieras

Pipeline de datos end-to-end utilizando el ecosistema de Apache Kafka para procesar transacciones financieras en tiempo real y detectar posibles casos de fraude.

##  Estructura del Proyecto

```
fraud_detector_r4/
├── connectors/                      # Configuraciones de Kafka Connect
│   ├── csv-source-connector.json   # Source connector para archivos CSV
│   ├── postgres-sink-connector.json # Sink connector para PostgreSQL
│   └── fraud-alerts-sink-connector.json # Sink connector para alertas de fraude
├── data/                            # Directorio de datos
│   ├── input/                       # Archivos CSV de entrada
│   ├── processed/                   # Archivos CSV procesados
│   └── error/                       # Archivos con errores
├── ksqldb/                          # Scripts de ksqlDB
│   ├── 01-create-streams.sql       # Creación de streams base
│   ├── 02-fraud-detection.sql      # Reglas de detección de fraude
│   └── 03-aggregations.sql         # Agregaciones y estadísticas
├── postgres/                        # Scripts de PostgreSQL
│   └── init-db.sql                 # Inicialización de base de datos
├── schemas/                         # JSON Schemas para Schema Registry
│   ├── transaction-value-schema.json # Schema de transacciones
│   └── README.md                    # Documentación de schemas
├── scripts/                         # Scripts de automatización
│   ├── create-env.sh               # Creación interactiva de .env
│   ├── deploy-connectors.sh        # Despliegue de conectores
│   ├── register-schema.sh          # Registro de schemas en Schema Registry
│   ├── run-ksql-scripts.sh         # Ejecución de scripts ksqlDB
│   ├── wait-for-services.sh        # Espera de servicios
│   ├── test-pipeline.sh            # Prueba completa del pipeline
│   └── validate-data-flow.sh       # Validación del flujo de datos
├── docker-compose.yml               # Configuración de contenedores
├── generate_test_data.py            # Generador de datos de prueba
├── generate_fraud_test_data.py      # Generador de casos específicos de fraude
├── setup.sh                         # Script de configuración inicial *
├── demo.sh                          # Script de demostración del pipeline *
└── README.md                        # Este archivo
```

##  Formato de Datos CSV

El sistema procesa archivos CSV con la siguiente estructura:

| Campo            | Tipo      | Descripción                                                  |
|-----------------|-----------|--------------------------------------------------------------|
| transaction_id  | VARCHAR   | ID único de transacción (ej: TXN_000001, FRAUD_001)        |
| account_id      | VARCHAR   | ID de cuenta (ej: ACC_0001)                                 |
| timestamp       | TIMESTAMP | Fecha y hora (formato: yyyy-MM-dd HH:mm:ss)                 |
| amount          | DECIMAL   | Monto de la transacción                                      |
| merchant_name   | VARCHAR   | Nombre del comercio                                          |
| transaction_type| VARCHAR   | Tipo: PURCHASE, WITHDRAWAL, TRANSFER, PAYMENT               |
| latitude        | DOUBLE    | Latitud de la ubicación de la transacción                   |
| longitude       | DOUBLE    | Longitud de la ubicación de la transacción                  |
| channel         | VARCHAR   | Canal: ATM, MOBILE, ONLINE, POS                             |
| status          | VARCHAR   | Estado: APPROVED, PENDING, DECLINED                         |

### Ejemplo de datos:

```csv
transaction_id,account_id,timestamp,amount,merchant_name,transaction_type,latitude,longitude,channel,status
TXN_000001,ACC_0001,2024-10-01 10:30:00,125.50,Walmart Supercenter,PURCHASE,40.7128,-74.0060,POS,APPROVED
FRAUD_001,ACC_0010,2024-10-01 15:45:00,15000.00,Amazon Web Services,PURCHASE,34.0522,-118.2437,ONLINE,APPROVED
TXN_000002,ACC_0002,2024-10-01 11:20:00,45.75,Starbucks Coffee,PURCHASE,41.8781,-87.6298,MOBILE,APPROVED
```

##  Inicio Rápido

### Instalación en 2 Pasos

#### Paso 1: Configurar el Sistema

```bash
# Configurar variables de entorno (primera vez)
./scripts/create-env.sh

# Configurar y levantar todo el pipeline
chmod +x setup.sh
./setup.sh
```

El script `setup.sh` realizará automáticamente:
- Levantamiento de servicios Docker
- Espera de servicios disponibles
- Registro de schemas en Schema Registry
- Despliegue de conectores de Kafka Connect
- Ejecución de scripts de ksqlDB

#### Paso 2: Ejecutar la Demo

```bash
# Ejecutar demostración completa del pipeline
chmod +x demo.sh
./demo.sh
```

El script `demo.sh`:
- Verifica que el sistema esté configurado
- Genera datos de prueba con casos específicos de fraude
- Procesa los datos a través del pipeline
- Muestra estadísticas y resultados en tiempo real
- Valida el flujo completo de datos

### Flujo Manual (Alternativo)

Si prefieres ejecutar los pasos manualmente:

```bash
# 1. Levantar servicios
docker-compose up -d

# 2. Esperar servicios
./scripts/wait-for-services.sh

# 3. Registrar schema
./scripts/register-schema.sh schemas/transaction-value-schema.json trx-fraud-transactions-value

# 4. Desplegar conectores
./scripts/deploy-connectors.sh

# 5. Ejecutar scripts ksqlDB
./scripts/run-ksql-scripts.sh

# 6. Generar datos de prueba
python3 generate_fraud_test_data.py

# 7. Validar pipeline
sleep 20
./scripts/validate-data-flow.sh
```

### Generar Datos Personalizados

```bash
# Generar 1000 transacciones (5% de fraude por defecto)
python generate_test_data.py -t 1000 -o data/input/transactions.csv

# Generar con tasa de fraude personalizada
python generate_test_data.py -t 5000 --fraud-rate 0.08 -o data/input/test_data.csv

# Ver ayuda
python generate_test_data.py --help
```

**Nota:** Por defecto, el script agrega automáticamente un timestamp al nombre del archivo para evitar sobrescribir archivos existentes. Usa la opción `--no-timestamp` si deseas usar el nombre exacto especificado.

### Monitorear el Sistema

**Kafka Control Center:**
- URL: http://localhost:9021
- Monitorea topics, conectores y rendimiento

**PostgreSQL:**
```bash
docker exec -it postgres psql -U kafka_user -d fraud_detection
```

**ksqlDB CLI:**
```bash
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

##  Scripts Automatizados

El proyecto incluye scripts bash para automatizar el setup y operación del pipeline. **Ver [`scripts/README.md`](scripts/README.md) para documentación completa.**

### Scripts de Setup
- **`scripts/create-env.sh`**: Creación interactiva del archivo `.env`
- **`scripts/wait-for-services.sh`**: Espera a que todos los servicios estén disponibles
- **`scripts/register-schema.sh`**: Registra schemas en Schema Registry
- **`scripts/deploy-connectors.sh`**: Despliega conectores de Kafka Connect
- **`scripts/run-ksql-scripts.sh`**: Ejecuta scripts de ksqlDB

### Scripts de Validación
- **`scripts/validate-data-flow.sh`**: Valida el flujo completo de datos
- **`scripts/test-pipeline.sh`**: Ejecuta prueba completa con datos generados

### Generadores de Datos
- **`generate_test_data.py`**: Genera datos sintéticos de prueba
- **`generate_fraud_test_data.py`**: Genera casos específicos para cada regla

### Uso Rápido
```bash
# Setup completo
docker-compose up -d && \
./scripts/wait-for-services.sh && \
./scripts/register-schema.sh schemas/transaction-value-schema.json trx-fraud-transactions-value && \
./scripts/deploy-connectors.sh && \
./scripts/run-ksql-scripts.sh

# Prueba con datos específicos
python3 generate_fraud_test_data.py
sleep 15
./scripts/validate-data-flow.sh
```

##  Reglas de Detección de Fraude

El sistema implementa **5 reglas principales** de detección de fraude en tiempo real:

### 1. Transacciones de Alto Valor
- **Condición:** Monto > $10,000
- **Severidad:** HIGH
- **Topic:** `fraud-high-value`
- **Campos guardados:** `transaction_id`, `account_id`, `amount`, y todos los detalles de la transacción

### 2. Frecuencia Anormal
- **Condición:** Más de 5 transacciones en 5 minutos
- **Severidad:** HIGH
- **Topic:** `fraud-high-frequency-table`
- **Campos guardados:** `account_id`, `transaction_ids` (array), `transaction_count`, `total_amount`, `window_start`, `window_end`

### 3. Múltiples Ubicaciones Simultáneas
- **Condición:** Más de 2 ubicaciones diferentes en 10 minutos
- **Severidad:** HIGH
- **Topic:** `fraud-multiple-locations-table`
- **Campos guardados:** `account_id`, `transaction_ids` (array), `locations` (array), `unique_locations`, `window_start`, `window_end`

### 4. Cambios Drásticos de Comportamiento
- **Condición:** Transacción 3x superior al promedio histórico (análisis en ventana de 1 hora)
- **Severidad:** MEDIUM
- **Topic:** `account-avg-amount-table`
- **Campos guardados:** `account_id`, `avg_amount`, `max_amount`, `min_amount`, `transaction_count`

### 5. Horarios Inusuales
- **Condición:** Transacciones entre 2AM-5AM
- **Severidad:** LOW
- **Topic:** `fraud-unusual-time`
- **Campos guardados:** `transaction_id`, `account_id`, `hour_of_day`, y todos los detalles de la transacción

##  Agregaciones y Estadísticas

El sistema genera múltiples streams de agregación:

- **account_statistics:** Estadísticas por cuenta (ventana 1 hora)
- **merchant_statistics:** Estadísticas por comerciante (ventana 1 hora)
- **location_statistics:** Estadísticas por ubicación (ventana 1 hora)
- **channel_statistics:** Estadísticas por canal (ventana 1 hora)
- **transaction_type_statistics:** Estadísticas por tipo de transacción
- **real_time_volume:** Volumen total en tiempo real (ventana 5 minutos)
- **velocity_check:** Verificación de velocidad (ventana 1 minuto)
- **daily_patterns:** Patrones por día de la semana

## 🗄 Base de Datos PostgreSQL

### Tablas Principales

1. **transactions:** Todas las transacciones procesadas
2. **fraud_alerts:** Alertas de fraude detectadas
3. **account_statistics:** Estadísticas agregadas por cuenta
4. **merchant_statistics:** Estadísticas agregadas por comerciante
5. **location_statistics:** Estadísticas agregadas por ubicación
6. **channel_statistics:** Estadísticas agregadas por canal

### Vistas Útiles

- **v_account_summary:** Resumen por cuenta
- **v_fraud_by_account:** Alertas de fraude por cuenta
- **v_suspicious_merchants:** Comerciantes con más fraude
- **v_recent_fraud_transactions:** Transacciones fraudulentas recientes
- **v_daily_statistics:** Estadísticas diarias
- **v_hourly_patterns:** Patrones horarios

### Funciones

```sql
-- Obtener transacciones recientes de una cuenta
SELECT * FROM get_account_recent_transactions('ACC_0001', 10);

-- Calcular tasa de fraude
SELECT * FROM calculate_fraud_rate();
```

##  Consultas ksqlDB Útiles

```sql
-- Ver todas las transacciones
SELECT * FROM transactions_stream EMIT CHANGES LIMIT 10;

-- Ver transacciones enriquecidas
SELECT * FROM transactions_stream_enriched EMIT CHANGES;

-- Ver alertas de fraude consolidadas
SELECT * FROM fraud_alerts_consolidated EMIT CHANGES;

-- Ver estadísticas de cuenta en tiempo real
SELECT * FROM account_statistics EMIT CHANGES;

-- Ver comerciantes más activos
SELECT merchant_name, transaction_count, total_volume 
FROM merchant_statistics EMIT CHANGES;

-- Ver volumen en tiempo real
SELECT * FROM real_time_volume EMIT CHANGES;

-- Ver alertas de velocidad
SELECT * FROM velocity_alerts EMIT CHANGES;

-- Ver estadísticas por canal
SELECT * FROM channel_statistics EMIT CHANGES;
```

##  Componentes Docker

- **Zookeeper:** Coordinación de Kafka
- **Kafka Broker:** Servidor de mensajería
- **Schema Registry:** Registro de esquemas
- **Kafka Connect:** Framework de conectores
- **ksqlDB Server:** Motor de procesamiento de streams
- **ksqlDB CLI:** Cliente de línea de comandos
- **Control Center:** Interfaz web de monitoreo
- **PostgreSQL:** Base de datos persistente

##  Configuración con Variables de Entorno

El proyecto utiliza **dos niveles** de configuración con variables de entorno:

### 1. Variables Globales (`.env`)
Archivo único para variables compartidas entre scripts y herramientas.

### 2. Variables por Servicio (`env.d/*.env`)
Cada contenedor Docker tiene su propio archivo de variables en el directorio `env.d/`.

### Creación de Archivos de Configuración

#### Opción 1: Variables Globales (.env)
Para scripts y herramientas del proyecto:

```bash
# Script interactivo (recomendado)
./create-env.sh

# O copiar manualmente
cp env.template .env
```

El script `create-env.sh`:
-  Verifica si `.env` existe y crea backup si es necesario
-  Copia el template con todos los valores por defecto
-  Muestra las configuraciones importantes a personalizar
-  Permite editar el archivo inmediatamente
-  Proporciona próximos pasos claros

#### Opción 2: Variables por Servicio (env.d/)
Para contenedores Docker - **YA ESTÁN CREADOS Y LISTOS**:

Los archivos en `env.d/` ya están configurados con valores por defecto. Solo necesitas modificarlos si:
- Cambias contraseñas (especialmente `postgres.env`)
- Ajustas configuración para producción
- Personalizas puertos o conexiones

```bash
# Ver archivos disponibles
ls -la env.d/

# Editar PostgreSQL (por ejemplo, cambiar contraseña)
nano env.d/postgres.env

# Editar Kafka
nano env.d/kafka.env
```

**Archivos disponibles:**
- `zookeeper.env` - Configuración de Zookeeper
- `kafka.env` - Configuración de Kafka Broker
- `schema-registry.env` - Schema Registry
- `kafka-connect.env` - Kafka Connect
- `ksqldb-server.env` - ksqlDB Server
- `postgres.env` - PostgreSQL  Cambiar contraseña en producción
- `adminer.env` - Adminer (UI PostgreSQL)
- `kafka-ui.env` - Kafka UI

 **Documentación detallada:** Ver `env.d/README.md`

### Variables Principales por Ubicación

#### Variables Globales (`.env`)
Usadas por scripts de setup y herramientas:

| Categoría | Variable | Valor por Defecto | Ubicación |
|-----------|----------|-------------------|-----------|
| **Topics** | `TRANSACTIONS_TOPIC` | trx-fraud-transactions | `.env` |
| | `FRAUD_ALERTS_TOPIC` | fraud-alerts | `.env` |
| | `TOPIC_PARTITIONS` | 3 | `.env` |
| **URLs** | `KAFKA_CONNECT_URL` | http://localhost:8083 | `.env` |
| | `KSQLDB_SERVER_URL` | http://localhost:8088 | `.env` |
| **Reintentos** | `MAX_RETRIES` | 30 | `.env` |
| | `RETRY_INTERVAL` | 2 | `.env` |

#### Variables por Servicio (env.d/)
Usadas por contenedores Docker:

| Servicio | Archivo | Variables Clave |
|----------|---------|-----------------|
| **Kafka** | `env.d/kafka.env` | `KAFKA_BROKER_ID`, `KAFKA_ADVERTISED_LISTENERS` |
| **PostgreSQL** | `env.d/postgres.env` | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`  |
| **Kafka Connect** | `env.d/kafka-connect.env` | `CONNECT_BOOTSTRAP_SERVERS`, `CONNECT_GROUP_ID` |
| **ksqlDB** | `env.d/ksqldb-server.env` | `KSQL_BOOTSTRAP_SERVERS`, `KSQL_SERVICE_ID` |
| **Zookeeper** | `env.d/zookeeper.env` | `ZOOKEEPER_CLIENT_PORT` |
| **Schema Registry** | `env.d/schema-registry.env` | `SCHEMA_REGISTRY_HOST_NAME` |
| **Adminer** | `env.d/adminer.env` | `ADMINER_DEFAULT_SERVER` |
| **Kafka UI** | `env.d/kafka-ui.env` | `KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS` |

### Variables de Fraude (Documentación)

Estas variables documentan los umbrales usados en las reglas de detección:

```env
FRAUD_HIGH_VALUE_THRESHOLD=10000
FRAUD_HIGH_FREQUENCY_COUNT=5
FRAUD_HIGH_FREQUENCY_WINDOW=5
FRAUD_MULTIPLE_LOCATIONS_COUNT=2
FRAUD_MULTIPLE_LOCATIONS_WINDOW=10
FRAUD_BEHAVIOR_MULTIPLIER=3
FRAUD_UNUSUAL_TIME_START=2
FRAUD_UNUSUAL_TIME_END=5
FRAUD_UNUSUAL_TIME_AMOUNT=1000
```

### Personalización

#### Variables Globales
Para scripts y herramientas:

```bash
# Editar variables globales
nano .env
# Modificar variables según necesites
```

#### Variables de Servicios Docker
Para configuración de contenedores:

```bash
# Cambiar contraseña de PostgreSQL (IMPORTANTE en producción)
nano env.d/postgres.env
# Modificar: POSTGRES_PASSWORD=mi_contraseña_segura

# Ajustar configuración de Kafka
nano env.d/kafka.env
# Modificar listeners si usas host remoto

# Personalizar Kafka Connect
nano env.d/kafka-connect.env
```

**Después de modificar archivos en `env.d/`:**
```bash
# Reiniciar servicios para aplicar cambios
docker-compose down
docker-compose up -d
```

### Uso de Variables

#### En Scripts
Los scripts cargan automáticamente variables del archivo `.env` global:

- `setup.sh`: Script principal
- `scripts/deploy-connectors.sh`: Despliegue de conectores
- `scripts/wait-for-services.sh`: Espera de servicios
- `scripts/run-ksql-scripts.sh`: Ejecución de ksqlDB

Si `.env` no existe, los scripts usan valores por defecto.

#### En Docker Compose
Los contenedores cargan variables desde archivos en `env.d/`:

```yaml
services:
  postgres:
    image: postgres:15-alpine
    env_file:
      - ./env.d/postgres.env  #  Variables específicas del servicio
```

Cada contenedor solo tiene acceso a sus propias variables, mejorando la seguridad y organización.

##  Notas Importantes

1. **Archivo .env:** Crear siempre el archivo `.env` antes de iniciar (`cp env.template .env`)
2. **Formato de CSV:** El archivo debe tener encabezados y usar coma como delimitador
3. **Coordenadas:** Latitude y longitude deben ser números decimales válidos
4. **Timestamp:** Debe seguir el formato `yyyy-MM-dd HH:mm:ss`
5. **IDs de Fraude:** Las transacciones fraudulentas usan el prefijo `FRAUD_`
6. **Ubicaciones:** El sistema calcula ubicaciones como concatenación de lat,lon
7. **Seguridad:** NO subir el archivo `.env` con contraseñas reales a repositorios públicos

##  Flujo de Datos

```
CSV File → Kafka Connect (Source) → Kafka Topic (trx-fraud-transactions) 
    ↓
ksqlDB Processing (Fraud Detection + Aggregations)
    ↓
Multiple Kafka Topics (fraud-*, *-statistics)
    ↓
Kafka Connect (Sink) → PostgreSQL
```

##  Troubleshooting

### Ver logs de conectores
```bash
docker logs kafka-connect
```

### Ver logs de ksqlDB
```bash
docker logs ksqldb-server
```

### Verificar estado de conectores
```bash
curl http://localhost:8083/connectors
curl http://localhost:8083/connectors/csv-source-connector/status
```

### Reiniciar un conector
```bash
curl -X POST http://localhost:8083/connectors/csv-source-connector/restart
```

##  Recursos Adicionales

- [Documentación de Kafka](https://kafka.apache.org/documentation/)
- [Documentación de ksqlDB](https://docs.ksqldb.io/)
- [Kafka Connect](https://docs.confluent.io/platform/current/connect/index.html)
- [PostgreSQL](https://www.postgresql.org/docs/)

##  Casos de Uso

Este sistema es ideal para:

- Detección de fraude en tiempo real
- Análisis de patrones de transacciones
- Monitoreo de actividad sospechosa
- Generación de alertas automáticas
- Análisis de comportamiento de clientes
- Reporting y analytics en tiempo real

## ⚡ Rendimiento

- Procesamiento en tiempo real < 100ms
- Soporte para millones de transacciones/día
- Ventanas de agregación configurables
- Escalabilidad horizontal con Kafka partitions

## 🔐 Seguridad

### Buenas Prácticas

1. **Variables de Entorno:**
   - El archivo `.env` está en `.gitignore` por defecto
   - NUNCA subir `.env` con contraseñas reales al repositorio
   - Usar `env.template` como referencia para otros desarrolladores

2. **Producción:**
   - Cambiar `POSTGRES_PASSWORD` a una contraseña segura
   - Usar Docker Secrets o Vault para gestión de secretos
   - Configurar autenticación en Kafka (SASL/SSL)
   - Habilitar cifrado en tránsito (SSL/TLS)

3. **Desarrollo:**
   - Las contraseñas por defecto son solo para desarrollo local
   - No exponer puertos innecesarios al exterior
   - Revisar logs regularmente

4. **Sistema:**
   - Validación de datos en conectores
   - Dead Letter Queue para errores
   - Logs de auditoría en PostgreSQL
   - Índices optimizados para consultas rápidas

##  Estructura de Archivos

```
fraud_detector_r4/
├── env.template              # Template de variables de entorno globales
├── .env                       # Variables de entorno globales (NO en git)
├── env.d/                     # Variables de entorno por servicio
│   ├── zookeeper.env         # Variables de Zookeeper
│   ├── kafka.env             # Variables de Kafka
│   ├── schema-registry.env   # Variables de Schema Registry
│   ├── kafka-connect.env     # Variables de Kafka Connect
│   ├── ksqldb-server.env     # Variables de ksqlDB
│   ├── postgres.env          # Variables de PostgreSQL
│   ├── adminer.env           # Variables de Adminer
│   ├── kafka-ui.env          # Variables de Kafka UI
│   └── README.md             # Documentación de env.d/
├── setup.sh                   # Script principal de setup
├── generate_test_data.py      # Generador de datos
├── docker-compose.yml         # Configuración de contenedores
├── connectors/                # Configuración de conectores
├── ksqldb/                    # Scripts de ksqlDB
├── postgres/                  # Scripts de PostgreSQL
├── scripts/                   # Scripts auxiliares
├── data/                      # Datos (input/processed/error)
└── README.md                  # Este archivo
```

---

**Desarrollado para el ecosistema Apache Kafka**

##  Archivos de Referencia

### Configuración
- **env.template**: Template completo de variables de entorno con todos los valores por defecto
- **create-env.sh**: Script interactivo para crear y configurar el archivo .env
