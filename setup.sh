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

# 1. Verificar que Minikube está corriendo
print_step "Verificando estado de Minikube..."
if ! minikube status >/dev/null 2>&1; then
    print_warning "Minikube no está corriendo. Iniciando..."
    minikube start --memory=4096 --cpus=2
else
    echo "Minikube ya está corriendo ✓"
fi

# 2. Aplicar configuración de Kubernetes
print_step "Aplicando configuración de Kubernetes..."
kubectl apply -f infra/k8s/citus-coordinator.yaml
kubectl apply -f infra/k8s/citus-worker.yaml

# 3. Dar tiempo para que Kubernetes cree los recursos
print_step "Esperando a que Kubernetes cree los recursos..."
sleep 6

# 4. Esperar a que los pods estén listos
print_step "Esperando a que los pods estén listos (esto puede tardar 2-3 minutos)..."

echo "Verificando que los pods se están creando..."
kubectl get pods -l app=citus-coordinator -o wide || echo "Aún no hay pods del coordinator"
kubectl get pods -l app=citus-worker -o wide || echo "Aún no hay pods de workers"

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
    print_error "Timeout esperando a los workers. Verificando estado..."
    echo "Estado actual de los pods (workers):"
    kubectl get pods -l app=citus-worker
    echo ""
    echo "Logs de los workers (últimos 30 lineas):"
    kubectl logs -l app=citus-worker --tail=30 || true
    # no abortamos: en algunos casos los workers tardan o algunos pods no son necesarios
fi

echo "Todos los pods Ready (o ya visibles) ✓"

# 5. Obtener nombre real del pod coordinator y worker pods dinámicos
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

# 8. Verificar si la base de datos ya existe (consulta limpia)
print_step "Verificando si la base de datos existe..."
DB_EXISTS_RAW=$(kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM pg_database WHERE datname='interop_db';" 2>/dev/null || echo "0")
# limpiar retornos y espacios
DB_EXISTS=$(printf "%s" "$DB_EXISTS_RAW" | tr -d '[:space:]' || echo "0")
echo "DEBUG: DB_EXISTS_RAW = '$DB_EXISTS_RAW'   -> DB_EXISTS = '$DB_EXISTS'"

# Si DB no existe, la creamos y aplicamos init SQL
if [ "$DB_EXISTS" -eq 0 ]; then
    print_step "Creando base de datos interop_db..."
    kubectl exec $COORDINATOR_POD -- psql -U postgres -d postgres -c "CREATE DATABASE interop_db;" \
      || { print_error "Fallo creando la base de datos interop_db"; exit 1; }

    # 9. Copiar y ejecutar script de inicialización
    if [ -f $INIT_SQL_LOCAL ]; then
        print_step "Copiando script de inicialización ($INIT_SQL_LOCAL) al pod..."
        kubectl cp $INIT_SQL_LOCAL $COORDINATOR_POD:/tmp/init.sql
        print_step "Ejecutando script de inicialización en interop_db..."
        # esperar que interop_db acepte conexiones
        tries=0
        while ! kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -t -A -c "SELECT 1;" >/dev/null 2>&1; do
            tries=$((tries+1))
            if [ $tries -ge 20 ]; then
                print_error "interop_db no acepta conexiones después de varios intentos"
                kubectl logs $COORDINATOR_POD --tail=80 || true
                exit 1
            fi
            sleep 1
        done

        kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -f /tmp/init.sql \
            || { print_error "Falló la ejecución de /tmp/init.sql"; kubectl logs "$COORDINATOR_POD" --tail=120 || true; exit 1; }
        print_step "Script de inicialización aplicado ✓"
    else
        print_warning "Archivo $INIT_SQL_LOCAL no encontrado en el host. Omitiendo ejecución del init."
    fi

    # 10. Verificar extensión citus (intentar)
    print_step "Verificando extensión Citus (versión)..."
    kubectl exec $COORDINATOR_POD -- psql -U postgres -d interop_db -t -A -c "SELECT citus_version();" >/dev/null 2>&1 && \
        print_step "Citus disponible ✓" || print_warning "No se pudo comprobar citus_version(); revisa si la extensión está instalada."

    # 11. Configurar workers en Citus (añadir nodos)
    print_step "Configurando workers en Citus (si no están ya añadidos)..."
    # Contar workers activos
    WORKERS_COUNT_RAW=$(kubectl exec $COORDINATOR_POD -- psql -U postgres -d interop_db -t -A -c "SELECT COUNT(*) FROM pg_dist_node;" 2>/dev/null || echo "0")
    WORKERS_COUNT=$(printf "%s" $WORKERS_COUNT_RAW | tr -d '[:space:]' || echo "0")
    echo "Workers registrados (raw) = $WORKERS_COUNT_RAW -> cleaned = $WORKERS_COUNT"

    if [ "$WORKERS_COUNT" -eq 0 ]; then
        # Obtener IPs de los workers y añadirlos
        WORKER_IPS=( $(kubectl get pods -l app=citus-worker -o jsonpath='{.items[*].status.podIP}') )
        if [ "${#WORKER_IPS[@]}" -eq 0 ]; then
            print_warning "No se encontraron IPs de workers para registrar. Revisa pods."
        else
            for ip in "${WORKER_IPS[@]}"; do
                print_step "Añadiendo worker $ip:5432 al coordinator (master_add_node)..."
                # Intentamos agregar; ignoramos fallo si ya existe
                kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -t -A -c "SELECT master_add_node('$ip', 5432);" >/dev/null 2>&1 || \
                  print_warning "master_add_node devolvió error (posiblemente ya estaba agregado): $ip"
            done
        fi
    else
        echo "Workers ya están registrados ✓ (count = $WORKERS_COUNT)"
    fi

    # Mostrar workers registrados (informativo)
    print_step "Workers registrados actualmente (pg_dist_node):"
    kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c "SELECT * FROM pg_dist_node;" || true

    # 12. Insertar datos de prueba (opcional)
    if [ -f "$SAMPLE_SQL_LOCAL" ]; then
        read -p "Se encontró $SAMPLE_SQL_LOCAL. ¿Deseas insertar datos de prueba? (s/N): " INSERT_DATA
        if [[ "$INSERT_DATA" =~ ^[sS](i)?$ ]]; then
            print_step "Copiando datos de prueba..."
            kubectl cp "$SAMPLE_SQL_LOCAL" "$COORDINATOR_POD":/tmp/load_sample_data.sql
            print_step "Insertando datos de prueba..."
            kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -f /tmp/datos_prueba.sql || print_warning "Inserción de datos de prueba falló."
        else
            print_step "Omitiendo carga de datos de prueba."
        fi
    else
        print_step "No se encontró $SAMPLE_SQL_LOCAL; omitiendo carga de ejemplo."
    fi

else
    echo "La base de datos interop_db ya existe ✓"
    print_warning "Para reiniciar desde cero, ejecuta: kubectl exec $COORDINATOR_POD -- psql -U postgres -c 'DROP DATABASE interop_db;'"

    # Verificar workers registrados (intento seguro)
    print_step "Verificando workers registrados..."
    set +e
    kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c "SELECT node_name, node_port FROM citus_get_active_worker_nodes();" || \
        kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c "SELECT * FROM pg_dist_node;" || print_warning "No fue posible listar nodos (tal vez la extensión Citus no está completamente inicializada)."
    set -e
fi

# 13. Obtener información de conexión
print_step "Obteniendo información de conexión..."
NODE_PORT=$(kubectl get svc citus-coordinator -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "N/A")

echo ""
echo "=========================================="
echo "  ✓ CONFIGURACIÓN COMPLETADA"
echo "=========================================="
echo ""

# 14. Verificación final - distribución de tablas
print_step "Verificando distribución de tablas en Citus (pg_dist_partition / pg_dist_shard)..."
kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c \
    "SELECT logicalrelid::text AS tabla, COALESCE(partmethod::text, '') AS metodo, partkey AS columna_distribucion FROM pg_dist_partition WHERE logicalrelid::text LIKE 'hcd.%' ORDER BY logicalrelid;" || true

echo ""
print_step "Verificando cantidad de shards por tabla..."
kubectl exec "$COORDINATOR_POD" -- psql -U postgres -d interop_db -c \
    "SELECT logicalrelid::text AS tabla, COUNT(*) AS num_shards FROM pg_dist_shard WHERE logicalrelid::text LIKE 'hcd.%' GROUP BY logicalrelid ORDER BY logicalrelid;" || true

echo ""
echo "Información de conexión:"
echo "  Host: $MINIKUBE_IP"
echo "  Port: $NODE_PORT"
echo "  Database: interop_db"
echo "  User: postgres"
echo "  Password: postgres"
echo ""
echo "Conectar desde tu máquina local (si NodePort expuesto):"
echo "  psql -h $MINIKUBE_IP -p $NODE_PORT -U postgres -d interop_db"
echo ""
echo "Comandos útiles:"
echo "  - Ver pods: kubectl get pods"
echo "  - Logs coordinator: kubectl logs -f $COORDINATOR_POD"
echo "  - Shell en coordinator: kubectl exec -it $COORDINATOR_POD -- bash"
echo "  - Conectar a BD: kubectl exec -it $COORDINATOR_POD -- psql -U postgres -d interop_db"
echo ""
echo "Para detener (sin perder datos):"
echo "  minikube stop"
echo ""
echo "Para reiniciar:"
echo "  minikube start"
echo "  bash setup.sh"
echo ""
echo "=========================================="
