# Guía Completa de Scripts del Pipeline de Detección de Fraude

## Índice
1. [Scripts de Configuración](#scripts-de-configuración)
2. [Scripts de Despliegue](#scripts-de-despliegue)
3. [Scripts de Validación](#scripts-de-validación)
4. [Scripts de Generación de Datos](#scripts-de-generación-de-datos)
5. [Flujo de Ejecución Completo](#flujo-de-ejecución-completo)

---

## Scripts de Configuración

### `scripts/create-env.sh`
**Propósito:** Crea el archivo `.env` desde el template con configuración interactiva.

**Uso:**
```bash
./scripts/create-env.sh
```

**Funcionalidad:**
- Verifica si `.env` existe y crea backup si es necesario
- Copia `env.template` a `.env`
- Muestra configuraciones importantes
- Permite editar el archivo inmediatamente
- Proporciona próximos pasos

**Cuándo usarlo:**
- Primera vez que configuras el proyecto
- Cuando necesitas recrear la configuración
- Después de clonar el repositorio

---

## Scripts de Despliegue

### `scripts/wait-for-services.sh`
**Propósito:** Espera a que todos los servicios estén disponibles antes de continuar.

**Uso:**
```bash
./scripts/wait-for-services.sh
```

**Servicios que verifica:**
- Zookeeper (puerto 2181)
- Kafka (puerto 9092)
- Schema Registry (puerto 8081)
- Kafka Connect (puerto 8083)
- ksqlDB Server (puerto 8088)
- PostgreSQL (puerto 5432)
- Plugins de Kafka Connect

**Configuración:**
```env
MAX_RETRIES=60           # Número máximo de reintentos
RETRY_INTERVAL=5         # Segundos entre reintentos
```

**Cuándo usarlo:**
- Después de `docker-compose up -d`
- Antes de desplegar conectores
- Antes de ejecutar scripts de ksqlDB

---

### `scripts/register-schema.sh`
**Propósito:** Registra schemas JSON en el Schema Registry.

**Uso:**
```bash
./scripts/register-schema.sh <schema-file> <subject-name>

# Ejemplo:
./scripts/register-schema.sh schemas/transaction-value-schema.json trx-fraud-transactions-value
```

**Funcionalidad:**
- Valida que el archivo JSON sea válido
- Registra el schema en Schema Registry
- Verifica el registro exitoso
- Muestra el ID y versión del schema

**Cuándo usarlo:**
- Antes de desplegar conectores que usen JSON Schema
- Cuando actualizas el schema de datos
- Al inicializar el pipeline

---

### `scripts/deploy-connectors.sh`
**Propósito:** Despliega todos los conectores de Kafka Connect.

**Uso:**
```bash
./scripts/deploy-connectors.sh
```

**Conectores que despliega:**
1. **csv-source-connector:** Lee archivos CSV del directorio `/data/input/`
2. **postgres-sink-connector:** Guarda transacciones en PostgreSQL
3. **fraud-alerts-sink-connector:** Guarda alertas de fraude en PostgreSQL

**Funcionalidad:**
- Espera a que Kafka Connect esté listo
- Elimina conectores existentes antes de crearlos
- Verifica el estado de cada conector
- Muestra si están en estado RUNNING o FAILED

**Cuándo usarlo:**
- Después de que los servicios estén disponibles
- Cuando actualizas la configuración de conectores
- Si necesitas reiniciar un conector

**Verificación manual:**
```bash
# Listar conectores
curl http://localhost:8083/connectors

# Ver estado de un conector
curl http://localhost:8083/connectors/csv-source-connector/status
```

---

### `scripts/run-ksql-scripts.sh`
**Propósito:** Ejecuta los scripts de ksqlDB en orden para crear streams y reglas de fraude.

**Uso:**
```bash
./scripts/run-ksql-scripts.sh
```

**Scripts que ejecuta (en orden):**
1. `ksqldb/01-create-streams.sql` - Crea streams base
2. `ksqldb/02-fraud-detection.sql` - Crea reglas de detección de fraude
3. `ksqldb/03-aggregations.sql` - Crea agregaciones y estadísticas

**Funcionalidad:**
- Espera a que ksqlDB Server esté disponible
- Ejecuta cada script via Docker CLI
- Verifica streams y tablas creados
- Muestra resumen de objetos creados

**Cuándo usarlo:**
- Después de desplegar conectores
- Cuando actualizas las reglas de fraude
- Para recrear los streams desde cero

**Verificación manual:**
```bash
# Conectarse a ksqlDB CLI
docker exec -it fraud-ksqldb-cli ksql http://fraud-ksqldb-server:8088

# Comandos útiles:
SHOW STREAMS;
SHOW TABLES;
SHOW QUERIES;
```

---

## Scripts de Validación

### `scripts/validate-data-flow.sh`
**Propósito:** Valida el flujo completo de datos en el pipeline.

**Uso:**
```bash
./scripts/validate-data-flow.sh
```

**Validaciones que realiza:**

1. **Archivos CSV:**
   - Archivos en `/data/input/`
   - Archivos procesados en `/data/processed/`
   - Archivos con error en `/data/error/`

2. **Conectores:**
   - Estado de csv-source-connector
   - Estado de postgres-sink-connector
   - Estado de fraud-alerts-sink-connector

3. **Tópicos de Kafka:**
   - Mensajes en `trx-fraud-transactions`
   - Mensajes en `fraud-alerts`
   - Mensajes en `fraud-high-value`

4. **Streams de ksqlDB:**
   - Número de streams creados
   - Listado de streams activos

5. **Tablas de ksqlDB:**
   - Número de tablas creadas
   - Listado de tablas de agregación

6. **PostgreSQL:**
   - Tablas creadas
   - Registros en `transactions`
   - Registros en `fraud_alerts`
   - Tipos de datos correctos

**Salida:**
```
Validaciones pasadas: X/6

El pipeline está funcionando correctamente
```

**Cuándo usarlo:**
- Después de procesar datos de prueba
- Para verificar el estado general del sistema
- Antes de procesar datos de producción
- Para troubleshooting

---

### `scripts/test-pipeline.sh`
**Propósito:** Ejecuta una prueba completa del pipeline con datos generados.

**Uso:**
```bash
./scripts/test-pipeline.sh [num_transacciones] [fraud_rate]

# Ejemplos:
./scripts/test-pipeline.sh                  # 50 transacciones, 10% fraude
./scripts/test-pipeline.sh 100              # 100 transacciones, 10% fraude
./scripts/test-pipeline.sh 200 0.15         # 200 transacciones, 15% fraude
```

**Flujo del script:**
1. Genera datos de prueba con `generate_test_data.py`
2. Verifica que el archivo se creó correctamente
3. Espera a que el connector procese el archivo
4. Verifica mensajes en Kafka
5. Verifica streams de ksqlDB
6. Verifica detección de fraude
7. Verifica datos en PostgreSQL
8. Muestra resumen completo

**Parámetros:**
- `num_transacciones`: Número de transacciones a generar (default: 50)
- `fraud_rate`: Tasa de fraude 0.0-1.0 (default: 0.10)

**Cuándo usarlo:**
- Para pruebas rápidas del pipeline completo
- Para validar cambios en las reglas de fraude
- Para generar datos de demo

---

## Scripts de Generación de Datos

### `generate_test_data.py`
**Propósito:** Genera datos sintéticos de transacciones para pruebas.

**Uso:**
```bash
python3 generate_test_data.py -t NUM_TRANSACTIONS -o OUTPUT_FILE [opciones]

# Ejemplos:
python3 generate_test_data.py -t 1000 -o data/input/test.csv
python3 generate_test_data.py -t 5000 --fraud-rate 0.08 -o data/input/batch.csv
python3 generate_test_data.py -t 100 --no-timestamp -o data/input/simple.csv
```

**Opciones:**
```
-t, --transactions NUM    Número de transacciones a generar
-o, --output FILE         Archivo de salida
--fraud-rate RATE         Tasa de fraude (0.0-1.0, default: 0.05)
--no-timestamp            No agregar timestamp al nombre del archivo
--help                    Muestra ayuda
```

**Tipos de fraude generados:**
- Transacciones de alto valor (>$10,000)
- Múltiples transacciones rápidas
- Ubicaciones geográficas variadas
- Horarios diversos

---

### `generate_fraud_test_data.py`
**Propósito:** Genera casos específicos para probar cada regla de fraude.

**Uso:**
```bash
python3 generate_fraud_test_data.py
```

**Casos que genera:**

| Regla | Casos | Descripción |
|-------|-------|-------------|
| REGLA 1 | 2 | Transacciones >$10,000 |
| REGLA 2 | 8 | 8 transacciones en 5 minutos de una cuenta |
| REGLA 3 | 4 | 4 transacciones en 4 ciudades diferentes |
| REGLA 5 | 2 | Transacciones a las 3AM |
| Normal | 20 | Transacciones normales para contexto |

**Total:** 36 transacciones

**Cuándo usarlo:**
- Para validar que cada regla funcione correctamente
- Para pruebas de desarrollo
- Para demos del sistema

---

## Flujo de Ejecución Completo

### Setup Inicial (Una sola vez)

```bash
# 1. Crear archivo de configuración
./scripts/create-env.sh

# 2. Iniciar servicios
docker-compose up -d

# 3. Esperar a que estén listos
./scripts/wait-for-services.sh

# 4. Registrar schemas
./scripts/register-schema.sh schemas/transaction-value-schema.json trx-fraud-transactions-value

# 5. Desplegar conectores
./scripts/deploy-connectors.sh

# 6. Ejecutar scripts de ksqlDB
./scripts/run-ksql-scripts.sh
```

### Procesamiento de Datos

```bash
# Opción 1: Generar datos de prueba
python3 generate_test_data.py -t 1000 -o data/input/transactions.csv

# Opción 2: Generar casos específicos de fraude
python3 generate_fraud_test_data.py

# Esperar unos segundos y validar
sleep 15
./scripts/validate-data-flow.sh
```

### Prueba Completa Automatizada

```bash
# Ejecuta todo el flujo de prueba
./scripts/test-pipeline.sh 100 0.10
```

### Troubleshooting

```bash
# Ver estado de conectores
curl http://localhost:8083/connectors/csv-source-connector/status | python3 -m json.tool

# Ver logs de un conector
docker logs fraud-kafka-connect | tail -50

# Ver logs de ksqlDB
docker logs fraud-ksqldb-server | tail -50

# Contar mensajes en un topic
docker exec fraud-kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic trx-fraud-transactions \
  --time -1

# Verificar datos en PostgreSQL
docker exec fraud-postgres psql -U kafka_user -d fraud_detection \
  -c "SELECT COUNT(*) FROM transactions;"

docker exec fraud-postgres psql -U kafka_user -d fraud_detection \
  -c "SELECT fraud_type, COUNT(*) FROM fraud_alerts GROUP BY fraud_type;"
```

### Reinicio Limpio

```bash
# Detener todo
docker-compose down -v

# Limpiar datos
rm -rf data/processed/*
rm -rf data/error/*

# Reiniciar desde el setup inicial
docker-compose up -d
./scripts/wait-for-services.sh
# ... continuar con setup inicial
```

---

## Variables de Entorno Importantes

### Para Scripts
```env
# URLs de servicios
KAFKA_CONNECT_URL=http://localhost:8083
KSQLDB_SERVER_URL=http://localhost:8088
SCHEMA_REGISTRY_URL=http://localhost:8081

# Topics
TRANSACTIONS_TOPIC=trx-fraud-transactions
FRAUD_ALERTS_TOPIC=fraud-alerts

# Configuración de reintentos
MAX_RETRIES=30
RETRY_INTERVAL=2
```

### Para Servicios Docker
Las variables de entorno para los contenedores Docker están en el directorio `env.d/`. Ver `env.d/README.md` para más detalles.

---

## Mejores Prácticas

1. **Siempre espera a que los servicios estén listos** antes de ejecutar scripts de despliegue
2. **Valida el flujo de datos** después de hacer cambios en las reglas de fraude
3. **Usa datos de prueba específicos** para validar cada regla individualmente
4. **Monitorea los logs** si algo no funciona como esperado
5. **Reinicia conectores** si cambian los schemas o configuraciones
6. **Verifica PostgreSQL** para confirmar que los datos se persisten correctamente

---

## Resumen de Comandos Útiles

```bash
# Setup completo
docker-compose up -d && ./scripts/wait-for-services.sh && \
./scripts/register-schema.sh schemas/transaction-value-schema.json trx-fraud-transactions-value && \
./scripts/deploy-connectors.sh && ./scripts/run-ksql-scripts.sh

# Generar y procesar datos de prueba
python3 generate_fraud_test_data.py && sleep 15 && ./scripts/validate-data-flow.sh

# Ver resultados en PostgreSQL
docker exec fraud-postgres psql -U kafka_user -d fraud_detection \
  -c "SELECT fraud_type, severity, COUNT(*) FROM fraud_alerts GROUP BY fraud_type, severity;"

# Reiniciar un conector
curl -X POST http://localhost:8083/connectors/csv-source-connector/restart

# Ver queries activas en ksqlDB
curl -s http://localhost:8088/ksql \
  -H 'Content-Type: application/vnd.ksql.v1+json' \
  -d '{"ksql":"SHOW QUERIES;"}' | python3 -m json.tool
```

---

**Nota:** Todos los scripts están diseñados para ser idempotentes y pueden ejecutarse múltiples veces sin causar problemas. Los scripts automáticamente cargan las variables de entorno del archivo `.env` si existe.

