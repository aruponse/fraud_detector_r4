# Archivos de Variables de Entorno por Servicio

Este directorio contiene archivos `.env` específicos para cada servicio del stack de Docker Compose.

##  Estructura

```
env.d/
├── README.md                 # Este archivo
├── zookeeper.env            # Variables de Zookeeper
├── kafka.env                # Variables de Kafka Broker
├── schema-registry.env      # Variables de Schema Registry
├── kafka-connect.env        # Variables de Kafka Connect
├── ksqldb-server.env        # Variables de ksqlDB Server
├── postgres.env             # Variables de PostgreSQL
├── adminer.env              # Variables de Adminer
└── kafka-ui.env             # Variables de Kafka UI
```

##  Propósito

Cada servicio tiene su propio archivo de variables de entorno para:

-  **Separación de responsabilidades**: Cada servicio tiene solo sus variables
-  **Facilidad de mantenimiento**: Es fácil encontrar y modificar variables específicas
-  **Claridad**: No hay variables mezcladas en el docker-compose.yml
-  **Seguridad**: Se pueden aplicar permisos diferentes a cada archivo
-  **Versionamiento**: Más fácil hacer seguimiento de cambios específicos

##  Descripción de Archivos

### zookeeper.env
Variables para Zookeeper (coordinación de Kafka):
- `ZOOKEEPER_CLIENT_PORT`: Puerto de cliente (2181)
- `ZOOKEEPER_TICK_TIME`: Intervalo de tick

### kafka.env
Variables para el Kafka Broker:
- `KAFKA_BROKER_ID`: ID del broker
- `KAFKA_ZOOKEEPER_CONNECT`: Conexión a Zookeeper
- `KAFKA_ADVERTISED_LISTENERS`: Listeners anunciados
- Y más configuraciones de Kafka

### schema-registry.env
Variables para Schema Registry:
- `SCHEMA_REGISTRY_HOST_NAME`: Hostname
- `SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS`: Bootstrap servers
- `SCHEMA_REGISTRY_LISTENERS`: Listeners

### kafka-connect.env
Variables para Kafka Connect:
- `CONNECT_BOOTSTRAP_SERVERS`: Bootstrap servers
- `CONNECT_GROUP_ID`: ID del grupo
- `CONNECT_KEY_CONVERTER` / `CONNECT_VALUE_CONVERTER`: Convertidores
- Topics de almacenamiento interno

### ksqldb-server.env
Variables para ksqlDB Server:
- `KSQL_BOOTSTRAP_SERVERS`: Bootstrap servers
- `KSQL_KSQL_SERVICE_ID`: ID del servicio
- `KSQL_KSQL_SCHEMA_REGISTRY_URL`: URL del Schema Registry
- Configuraciones de logging y streams

### postgres.env
Variables para PostgreSQL:
- `POSTGRES_DB`: Nombre de la base de datos
- `POSTGRES_USER`: Usuario
- `POSTGRES_PASSWORD`: Contraseña  **CAMBIAR EN PRODUCCIÓN**
- `PGDATA`: Directorio de datos

### adminer.env
Variables para Adminer (UI de PostgreSQL):
- `ADMINER_DEFAULT_SERVER`: Servidor por defecto

### kafka-ui.env
Variables para Kafka UI:
- `KAFKA_CLUSTERS_0_NAME`: Nombre del cluster
- `KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS`: Bootstrap servers
- `KAFKA_CLUSTERS_0_ZOOKEEPER`: Conexión a Zookeeper

##  Modificación

### Para Desarrollo
Los valores por defecto están listos para usar. No necesitas modificar nada.

### Para Producción

1. **PostgreSQL** (`postgres.env`):
   ```bash
   nano env.d/postgres.env
   # Cambiar: POSTGRES_PASSWORD=<contraseña_segura>
   ```

2. **Kafka** (`kafka.env`):
   ```bash
   nano env.d/kafka.env
   # Ajustar: KAFKA_ADVERTISED_LISTENERS si usas host remoto
   ```

3. **Memoria y Performance**:
   - Estos ajustes se hacen en `docker-compose.yml` (sección `deploy.resources`)

##  Seguridad

### Permisos Recomendados

```bash
# Restringir acceso a archivos con contraseñas
chmod 600 env.d/postgres.env

# Permisos normales para otros archivos
chmod 644 env.d/*.env
```

### Buenas Prácticas

1. **NO subir contraseñas reales a git**
   - Los archivos `.env` en `env.d/` están en `.gitignore`
   - Solo subir templates con valores de desarrollo

2. **Usar secrets en producción**
   - Docker Secrets
   - Kubernetes Secrets
   - Vault u otro gestor de secretos

3. **Rotar contraseñas regularmente**
   - Especialmente `POSTGRES_PASSWORD`

##  Uso

El docker-compose.yml usa estos archivos automáticamente:

```yaml
services:
  postgres:
    image: postgres:15-alpine
    env_file:
      - ./env.d/postgres.env
    # ... resto de configuración
```

No necesitas hacer nada especial. Solo ejecuta:

```bash
docker-compose up -d
```

##  Cambios en Variables

Si modificas algún archivo `.env`:

```bash
# 1. Detener los servicios
docker-compose down

# 2. Iniciar con nuevas variables
docker-compose up -d

# 3. Verificar logs
docker-compose logs -f [servicio]
```

##  Variables de Entorno vs Argumentos

### ¿Por qué archivos .env separados?

**Antes** (variables en docker-compose.yml):
```yaml
services:
  postgres:
    environment:
      POSTGRES_DB: fraud_detection
      POSTGRES_USER: kafka_user
      POSTGRES_PASSWORD: kafka_pass  #  Visible en el YML
```

**Ahora** (archivos .env):
```yaml
services:
  postgres:
    env_file:
      - ./env.d/postgres.env  #  Variables en archivo separado
```

### Ventajas:
-  Variables fuera del docker-compose.yml
-  Más fácil de mantener
-  Mejor para versionamiento
-  Archivo .env puede estar en .gitignore
-  Diferentes permisos por archivo

##  Verificación

### Ver variables de un contenedor:

```bash
# PostgreSQL
docker exec fraud-postgres env | grep POSTGRES

# Kafka
docker exec fraud-kafka env | grep KAFKA

# ksqlDB
docker exec fraud-ksqldb-server env | grep KSQL
```

### Ver contenido de archivo .env:

```bash
cat env.d/postgres.env
cat env.d/kafka.env
```

##  Referencias

- Docker Compose: [Environment files](https://docs.docker.com/compose/environment-variables/#the-env-file)
- Confluent Kafka: [Configuration Reference](https://docs.confluent.io/platform/current/installation/configuration/)
- PostgreSQL: [Environment Variables](https://www.postgresql.org/docs/current/libpq-envars.html)

##  Importante

1. **Backups**: Haz backup de estos archivos antes de modificar
2. **Testing**: Prueba cambios en desarrollo antes de producción
3. **Documentación**: Documenta cambios personalizados
4. **Secrets**: Nunca pongas secretos reales en git

---

**¿Dudas?** Consulta el README.md principal del proyecto.


