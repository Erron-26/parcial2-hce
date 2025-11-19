#!/usr/bin/env bash
# setup-citus-fixed.sh
# Script de automatización para Citus en Minikube (versión corregida)
# Ejecutar con: bash setup-citus-fixed.sh

set -euo pipefail
IFS=$'\n\t'

echo "=========================================="
echo "  SETUP AUTOMATIZADO DE CITUS EN MINIKUBE"
echo "=========================================="

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_step() {
    printf "%b\n" "${GREEN}[PASO]${NC} $1"
}

print_warning() {
    printf "%b\n" "${YELLOW}[ADVERTENCIA]${NC} $1"
}

print_error() {
    printf "%b\n" "${RED}[ERROR]${NC} $1"
}

# ---------------------------
# Configurables / paths
# ---------------------------
# Si usas otro nombre para el sql, ajusta aquí
INIT_SQL_LOCAL="${INIT_SQL_LOCAL:-infra/init.sql}"   # archivo SQL local que quieres copiar
SAMPLE_SQL_LOCAL="${SAMPLE_SQL_LOCAL:-infra/load_sample_data.sql}" # archivo de datos de prueba (opcional)

# 1. Verificar que Docker está corriendo
print_step "Verificando que Docker daemon esté corriendo..."
if ! docker info >/dev/null 2>&1; then
    print_error "El daemon de Docker no está corriendo o no se puede acceder a él."
    print_error "Por favor, inicia Docker y vuelve a ejecutar el script."
    exit 1
else
    echo "Docker está corriendo ✓"
fi

# 2. Verificar que Minikube está corriendo
print_step "Verificando estado de Minikube..."
if ! minikube status >/dev/null 2>&1; then
    print_warning "Minikube no está corriendo. Iniciando..."
    # Forzar una versión estable de Kubernetes para evitar problemas de compatibilidad
    minikube start --memory=4096 --cpus=2 --kubernetes-version=v1.28.3
else
    echo "Minikube ya está corriendo ✓"
fi

# 3. Construir y cargar imagen de la app FastAPI
print_step "Construyendo la imagen Docker 'middleware-citus:1.0'..."
# Apuntar el shell local al entorno de Docker de Minikube
eval $(minikube -p minikube docker-env --shell bash)
# Construir la imagen. El 'contexto' es el directorio raíz del proyecto.
docker build -t middleware-citus:1.0 -f backend/Dockerfile .
print_step "Imagen construida y disponible en Minikube ✓"


# 4. Aplicar configuración de Kubernetes
print_step "Aplicando configuración de Kubernetes (Citus y FastAPI)..."
kubectl apply -f infra/k8s/citus-coordinator.yaml
kubectl apply -f infra/k8s/citus-worker.yaml
kubectl apply -f infra/k8s/fastapi-deployment.yaml
kubectl apply -f infra/k8s/fastapi-service.yaml

# 5. Dar tiempo para que Kubernetes cree los recursos
print_step "Esperando a que Kubernetes cree los recursos..."
sleep 6

# 6. Esperar a que los pods estén listos
print_step "Esperando a que los pods estén listos (esto puede tardar 2-3 minutos)..."

echo "Verificando que los pods se están creando..."
kubectl get pods -l app=citus-coordinator -o wide || echo "Aún no hay pods del coordinator"
kubectl get pods -l app=citus-worker -o wide || echo "Aún no hay pods de workers"
kubectl get pods -l app=fastapi-app -o wide || echo "Aún no hay pods de la app FastAPI"

echo ""
echo "Esperando a que los pods estén en estado Ready..."
echo ""

# Esperar el coordinator
if ! kubectl wait --for=condition=ready pod -l app=citus-coordinator --timeout=300s >/dev/null 2>&1; then
    print_error "Timeout esperando al coordinator. Verificando estado..."
    echo "Estado actual de los pods (coordinator):"
    kubectl get pods -l app=citus-coordinator
    echo ""
    echo "Logs del coordinator:"
    COORD_POD=$(kubectl get pods -l app=citus-coordinator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -n "$COORD_POD" ]; then
        kubectl logs "$COORD_POD" --tail=80 || true
    fi
    exit 1
fi

# Esperar workers
if ! kubectl wait --for=condition=ready pod -l app=citus-worker --timeout=300s >/dev/null 2>&1; then
    print_warning "Timeout esperando a los workers. Se continuará, pero puede que no funcionen."
fi

# Esperar la app FastAPI
if ! kubectl wait --for=condition=ready pod -l app=fastapi-app --timeout=300s >/dev/null 2>&1; then
    print_error "Timeout esperando a la app FastAPI. Verificando estado..."
    echo "Estado actual de los pods (fastapi-app):"
    kubectl get pods -l app=fastapi-app
    echo ""
    echo "Logs de la app FastAPI:"
    FASTAPI_POD=$(kubectl get pods -l app=fastapi-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -n "$FASTAPI_POD" ]; then
        kubectl logs "$FASTAPI_POD" --tail=80 || true
    fi
    exit 1
fi

echo "Todos los pods principales están Ready ✓"

# 7. Obtener nombre real del pod coordinator y worker pods dinámicos
COORDINATOR_POD=$(kubectl get pods -l app=citus-coordinator -o jsonpath='{.items[0].metadata.name}')
if [ -z "$COORDINATOR_POD" ]; then
    print_error "No se detectó pod coordinador. Abortando."
    exit 1
fi

# Detectar pods workers reales
WORKER_PODS=( $(kubectl get pods -l app=citus-worker -o jsonpath='{.items[*].metadata.name}') )
# If no workers found, keep array empty
if [ "${#WORKER_PODS[@]}" -eq 0 ]; then
    print_warning "No se detectaron pods worker con la etiqueta app=citus-worker. Continúo, pero revisa esto."
fi

echo "Pods detectados:"
echo "  - Coordinator: $COORDINATOR_POD"
if [ "${#WORKER_PODS[@]}" -gt 0 ]; then
  for w in "${WORKER_PODS[@]}"; do
    echo "  - Worker: $w"
  done
fi
echo "  - FastAPI App: $(kubectl get pods -l app=fastapi-app -o jsonpath='{.items[0].metadata.name}')"

# 6. Esperar a que PostgreSQL esté listo en el coordinador (pg_isready o psql)
print_step "Esperando a que PostgreSQL esté listo en el coordinador..."
RETRY_COUNT=0
MAX_RETRIES=40
while true; do
    # usar pg_isready si disponible
    if kubectl exec $COORDINATOR_POD -- pg_isready -U postgres >/dev/null 2>&1; then
        print_step "PostgreSQL está respondiendo en el coordinator ✓"
        sleep 1
        break
    fi

    # intentar con psql - ejecutar SELECT 1 en 'postgres'
    if kubectl exec $COORDINATOR_POD -- psql -U postgres -d postgres -t -A -c "SELECT 1;" >/dev/null 2>&1; then
        print_step "Postgres responde (psql) ✓"
        break
    fi

    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        print_error "PostgreSQL no está respondiendo después de $MAX_RETRIES intentos"
        print_error "Últimos logs del pod coordinator:"
        kubectl logs "$COORDINATOR_POD" --tail=80 || true
        exit 1
    fi

    printf "PostgreSQL aún no está listo. Intento %s/%s. Reintentando en 5 segundos...\n" "$((RETRY_COUNT+1))" "$MAX_RETRIES"
    sleep 5
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

# 7. Esperar a que PostgreSQL esté listo en cada worker (si existen pods)
# Obtener pods workers como array (uno por línea)
mapfile -t WORKER_PODS < <(kubectl get pods -l app=citus-worker -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')

if [ "${#WORKER_PODS[@]}" -eq 0 ]; then
    print_warning "No se detectaron pods worker con la etiqueta app=citus-worker."
fi

for WPOD in "${WORKER_PODS[@]}"; do
    RETRY_COUNT=0
    while true; do
        # Intento 1: pg_isready (si existe en la imagen)
        if kubectl exec "$WPOD" -- pg_isready -U postgres >/dev/null 2>&1; then
            echo "Worker $WPOD responde (pg_isready) ✓"
            break
        fi

        # Intento 2 (fallback): ejecutar SELECT 1 en la BD 'postgres' con psql
        if kubectl exec "$WPOD" -- psql -U postgres -d postgres -t -A -c "SELECT 1;" >/dev/null 2>&1; then
            echo "Worker $WPOD responde (psql) ✓"
            break
        fi

        if [ $RETRY_COUNT -ge 20 ]; then
            print_warning "Worker $WPOD no responde tras varios intentos. Continuo (puede estar aún arrancando)."
            break
        fi

        sleep 3
        RETRY_COUNT=$((RETRY_COUNT + 1))
    done
done

# 8. Asegurar que la base de datos y el esquema existen
print_step "Asegurando que la base de datos 'interop_db' y sus tablas existen..."

# El contenedor de Citus crea la base de datos 'interop_db' automáticamente.
# Solo necesitamos esperar a que acepte conexiones.
tries=0
while ! kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -t -A -c "SELECT 1;" >/dev/null 2>&1; do
    tries=$((tries+1))
    if [ $tries -ge 25 ]; then
        print_error "'interop_db' no acepta conexiones después de varios intentos."
        print_error "Esto puede pasar si el pod está en un mal estado. Logs del coordinador:"
        kubectl logs "$COORDINATOR_POD" --tail=80 || true
        exit 1
    fi
    printf "'interop_db' aún no está lista. Intento %s/25. Reintentando en 5 segundos...\n" "$tries"
    sleep 5
done
print_step "'interop_db' está lista y aceptando conexiones ✓"

# Ahora, ejecutar SIEMPRE el script de inicialización. Es idempotente (usa IF NOT EXISTS).
# Esto asegura que las tablas se creen sin importar cómo se creó la base de datos.
if [ -f "$INIT_SQL_LOCAL" ]; then
    print_step "Copiando y ejecutando script de inicialización ($INIT_SQL_LOCAL)..."
    kubectl cp "$INIT_SQL_LOCAL" "$COORDINATOR_POD":/tmp/init.sql
    
    # Usamos -v ON_ERROR_STOP=1 para que el script falle si hay cualquier error en el SQL
    kubectl exec "$COORDINATOR_POD" -- bash -c "export PGPASSWORD=postgres && psql -v ON_ERROR_STOP=1 -U postgres -d interop_db -f /tmp/init.sql" \
        || { print_error "Falló la ejecución de /tmp/init.sql. El script se detendrá."; kubectl logs "$COORDINATOR_POD" --tail=120 || true; exit 1; }
    
    print_step "Script de inicialización aplicado ✓"
else
    print_error "Archivo de inicialización '$INIT_SQL_LOCAL' no encontrado. No se pueden crear las tablas. Abortando."
    exit 1
fi

# 9. Crear base de datos y extensiones en los workers (si no existen)
print_step "Asegurando que la base de datos y extensiones existen en los workers..."
for WPOD in "${WORKER_PODS[@]}"; do
    echo "Verificando worker $WPOD..."
    # Crear base de datos (ignorar error si ya existe)
    PGPASSWORD=postgres kubectl exec "$WPOD" -- psql -U postgres -d postgres -c "CREATE DATABASE interop_db;" >/dev/null 2>&1 || true
    # Crear extensiones (ignorar error si ya existen)
    PGPASSWORD=postgres kubectl exec "$WPOD" -- psql -U postgres -d interop_db -c "CREATE EXTENSION IF NOT EXISTS citus;" >/dev/null 2>&1 || true
    echo "Worker $WPOD verificado ✓"
done

# 10. Registrar workers en el coordinador (si no están registrados)
print_step "Verificando registro de workers en el coordinador..."
WORKERS_COUNT_RAW=$(kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -t -A -c "SELECT COUNT(*) FROM pg_dist_node WHERE nodename LIKE 'citus-worker%';" 2>/dev/null || echo "0")
WORKERS_COUNT=$(printf "%s" "$WORKERS_COUNT_RAW" | tr -d '[:space:]' || echo "0")
echo "Workers registrados actualmente: $WORKERS_COUNT"

if [ "$WORKERS_COUNT" -eq 0 ] && [ "${#WORKER_PODS[@]}" -gt 0 ]; then
    print_step "No hay workers registrados. Añadiendo..."
    # Usar DNS names predecibles del StatefulSet
    for i in $(seq 0 $((${#WORKER_PODS[@]} - 1))); do
        WORKER_DNS="citus-worker-${i}.citus-worker.default.svc.cluster.local"
        print_step "Añadiendo worker $WORKER_DNS:5432 al coordinator..."
        
        RESULT=$(PGPASSWORD=postgres kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c "SELECT master_add_node('$WORKER_DNS', 5432);" 2>&1)
        
        if echo "$RESULT" | grep -q "ERROR"; then
            print_error "Error al añadir worker $WORKER_DNS: $RESULT"
        else
            echo "Worker $WORKER_DNS añadido ✓"
        fi
    done
else
    print_step "Los workers ya están registrados o no se detectaron pods de worker. ✓"
fi

# Mostrar workers registrados (informativo)
print_step "Workers registrados actualmente (pg_dist_node):"
kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c "SELECT nodeid, nodename, nodeport, isactive FROM pg_dist_node;" || true

# 11. Distribuir tablas (si no están distribuidas)
print_step "Verificando distribución de tablas..."
DIST_TABLE_COUNT_RAW=$(kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -t -A -c "SELECT COUNT(*) FROM pg_dist_partition WHERE logicalrelid::text LIKE 'hcd.%';" 2>/dev/null || echo "0")
DIST_TABLE_COUNT=$(printf "%s" "$DIST_TABLE_COUNT_RAW" | tr -d '[:space:]' || echo "0")
echo "Tablas distribuidas actualmente: $DIST_TABLE_COUNT"

# Re-verificar cantidad de workers antes de distribuir
FINAL_WORKER_COUNT_RAW=$(kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -t -A -c "SELECT COUNT(*) FROM pg_dist_node WHERE nodename LIKE 'citus-worker%';" 2>/dev/null || echo "0")
FINAL_WORKER_COUNT=$(printf "%s" "$FINAL_WORKER_COUNT_RAW" | tr -d '[:space:]' || echo "0")

if [ "$DIST_TABLE_COUNT" -eq 0 ] && [ "$FINAL_WORKER_COUNT" -gt 0 ]; then
    print_step "No hay tablas distribuidas y hay workers disponibles. Distribuyendo una por una..."
    
    set +e # Desactivar exit on error temporalmente para capturar fallos
    
    kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c "SELECT create_reference_table('hcd.profesional_salud');"
    kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c "SELECT create_distributed_table('hcd.usuario', 'documento_id');"
    kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c "SELECT create_distributed_table('hcd.atencion', 'documento_id');"
    kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c "SELECT create_distributed_table('hcd.diagnostico', 'documento_id', colocate_with => 'hcd.atencion');"
    kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c "SELECT create_distributed_table('hcd.tecnologia_salud', 'documento_id', colocate_with => 'hcd.atencion');"
    kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c "SELECT create_distributed_table('hcd.egreso', 'documento_id', colocate_with => 'hcd.atencion');"
    
    set -e # Reactivar exit on error

    # Pequeña pausa para que los metadatos se asienten
    sleep 5
    
    # Re-verificar si la distribución tuvo éxito
    RECHECK_DIST_TABLE_COUNT_RAW=$(kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -t -A -c "SELECT COUNT(*) FROM pg_dist_partition WHERE logicalrelid::text LIKE 'hcd.%';" 2>/dev/null || echo "0")
    RECHECK_DIST_TABLE_COUNT=$(printf "%s" "$RECHECK_DIST_TABLE_COUNT_RAW" | tr -d '[:space:]' || echo "0")

    if [ "$RECHECK_DIST_TABLE_COUNT" -gt 0 ]; then
        print_step "Tablas distribuidas ✓"
    else
        print_error "La distribución de tablas parece haber fallado. Revisa los logs."
    fi
else
    if [ "$FINAL_WORKER_COUNT" -eq 0 ]; then
        print_warning "No se distribuyeron las tablas porque no hay workers registrados."
    else
        print_step "Las tablas ya parecen estar distribuidas. ✓"
    fi
fi

# 12. Insertar datos de prueba (opcional)
if [ -f "$SAMPLE_SQL_LOCAL" ]; then
    # Verificar si ya hay datos para no preguntar de nuevo si no es necesario
    USER_COUNT_RAW=$(kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -t -A -c "SELECT COUNT(*) FROM hcd.usuario;" 2>/dev/null || echo "0")
    USER_COUNT=$(printf "%s" "$USER_COUNT_RAW" | tr -d '[:space:]' || echo "0")

    if [ "$USER_COUNT" -eq 0 ]; then
        read -p "Se encontró '$SAMPLE_SQL_LOCAL'. ¿Deseas insertar datos de prueba? (s/N): " INSERT_DATA
        if [[ "$INSERT_DATA" =~ ^[sS](i)?$ ]]; then
            print_step "Copiando y ejecutando script de datos de prueba..."
            kubectl cp "$SAMPLE_SQL_LOCAL" "$COORDINATOR_POD":/tmp/load_sample_data.sql
            
            # Ejecutar con manejo de errores mejorado
            if ! kubectl exec "$COORDINATOR_POD" -- psql -v ON_ERROR_STOP=1 -U postgres -d interop_db -f /tmp/load_sample_data.sql; then
                print_error "Falló la inserción de datos de prueba desde '$SAMPLE_SQL_LOCAL'."
                print_error "Revisa el archivo SQL en busca de errores o violaciones de constraints."
                print_warning "El script continuará, pero la base de datos estará vacía."
            else
                print_step "Datos de prueba insertados correctamente. ✓"
            fi
        else
            print_step "Omitiendo carga de datos de prueba."
        fi
    else
        print_step "Ya existen datos en la tabla 'hcd.usuario', omitiendo inserción de datos de prueba."
    fi
else
    print_warning "No se encontró '$SAMPLE_SQL_LOCAL'; se omite la carga de datos de prueba."
fi

# 13. Generar archivo .env automáticamente
print_step "Generando archivo de entorno 'backend/.env'..."
DB_NODE_PORT=$(kubectl get svc citus-coordinator -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "127.0.0.1")

if [ "$DB_NODE_PORT" = "N/A" ] || [ "$MINIKUBE_IP" = "127.0.0.1" ]; then
    print_error "No se pudo obtener la IP de Minikube o el puerto del servicio de la base de datos."
    print_error "No se pudo generar el .env. Revisa la configuración de Minikube."
    exit 1
fi

# Crear el archivo .env
cat > backend/.env << EOF
# Este archivo es generado automáticamente por setup.sh
DB_HOST=${MINIKUBE_IP}
DB_PORT=${DB_NODE_PORT}
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=interop_db
SECRET_KEY=super-secret-key-for-development
EOF

print_step "Archivo 'backend/.env' generado exitosamente. ✓"


# 14. Obtener información de conexión de la App
print_step "Obteniendo información de conexión de la aplicación..."
APP_NODE_PORT=$(kubectl get svc fastapi-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")

echo ""
echo "=========================================="
echo "  ✓ CONFIGURACIÓN COMPLETADA"
echo "=========================================="
echo ""
echo "Información de la Base de Datos (para psql):"
echo "  Host: $MINIKUBE_IP"
echo "  Port: $DB_NODE_PORT"
echo ""
echo "Información de la Aplicación FastAPI:"
echo "  URL: http://$MINIKUBE_IP:$APP_NODE_PORT"
echo ""
echo "Próximos pasos:"
echo "  - Activa el entorno virtual: source backend/.venv/bin/activate.fish"
echo "  - Crea los usuarios: python3 backend/scripts/create_test_user.py (y los otros)"
echo "  - ¡Prueba la aplicación en la URL de arriba!"
echo ""
echo "=========================================="
