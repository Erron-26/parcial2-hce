#!/bin/bash
# setup-citus.sh
# Script de automatización completa para Citus en Minikube

set -e  # Salir si hay errores

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
    echo -e "${GREEN}[PASO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Verificar que Minikube está corriendo
print_step "Verificando estado de Minikube..."
if ! minikube status > /dev/null 2>&1; then
    print_warning "Minikube no está corriendo. Iniciando..."
    minikube start --memory=4096 --cpus=2
else
    echo "Minikube ya está corriendo ✓"
fi

# 2. Aplicar configuración de Kubernetes
print_step "Aplicando configuración de Kubernetes..."
kubectl apply -f infra/k8s/citus-coordinator.yaml
kubectl apply -f infra/k8s/citus-worker.yaml

# 3. Esperar a que los pods estén listos
print_step "Esperando a que los pods estén listos (esto puede tardar 2-3 minutos)..."
kubectl wait --for=condition=ready pod -l app=citus-coordinator --timeout=300s
kubectl wait --for=condition=ready pod -l app=citus-worker --timeout=300s

echo "Todos los pods están listos ✓"

# 4. Obtener nombres de pods
COORDINATOR_POD=$(kubectl get pods -l app=citus-coordinator -o jsonpath='{.items[0].metadata.name}')
WORKER_0="citus-worker-0"
WORKER_1="citus-worker-1"

echo "Pods detectados:"
echo "  - Coordinator: $COORDINATOR_POD"
echo "  - Worker 0: $WORKER_0"
echo "  - Worker 1: $WORKER_1"

# 5. Esperar a que PostgreSQL esté listo en el coordinador
print_step "Esperando a que PostgreSQL esté listo en el coordinador..."
RETRY_COUNT=0
MAX_RETRIES=60  # Aumentado a 60 intentos

# Verificar el estado del pod
print_step "Verificando estado del pod coordinador..."
kubectl describe pod $COORDINATOR_POD

# Dar tiempo adicional para la inicialización
print_step "Esperando 30 segundos para la inicialización completa..."
sleep 30

while true; do
    if kubectl exec $COORDINATOR_POD -- pg_isready -h localhost -U postgres > /dev/null 2>&1; then
        print_step "PostgreSQL está respondiendo..."
        # Esperar 5 segundos más para asegurar estabilidad
        sleep 5
        break
    fi
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_error "PostgreSQL no está respondiendo después de $MAX_RETRIES intentos"
        print_error "Últimos logs del pod:"
        kubectl logs $COORDINATOR_POD --tail=20
        exit 1
    fi
    
    print_warning "PostgreSQL aún no está listo. Intento $RETRY_COUNT de $MAX_RETRIES. Reintentando en 5 segundos..."
    sleep 5
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

print_step "PostgreSQL está listo. Verificando si la base de datos existe..."
DB_EXISTS=$(kubectl exec $COORDINATOR_POD -- psql -h localhost -U postgres -XtAc "SELECT 1 FROM pg_database WHERE datname='interop_db'" | grep -c 1)

if [ "$DB_EXISTS" -eq 0 ]; then
    print_step "Creando base de datos interop_db..."
    kubectl exec -it $COORDINATOR_POD -- psql -h localhost -U postgres -c "CREATE DATABASE interop_db;"
    
    # 6. Copiar y ejecutar script de inicialización
    print_step "Copiando script de inicialización al pod..."
    kubectl cp infra/init.sql $COORDINATOR_POD:/tmp/init.sql
    
    print_step "Ejecutando script de inicialización..."
    kubectl exec -it $COORDINATOR_POD -- psql -h localhost -U postgres -d interop_db -f /tmp/init.sql
    
    # 7. Configurar workers en Citus
    print_step "Agregando workers al cluster Citus..."
    kubectl exec -it $COORDINATOR_POD -- psql -h localhost -U postgres -d interop_db -c "SELECT * from master_add_node('citus-worker-0.citus-worker.default.svc.cluster.local', 5432);"
    kubectl exec -it $COORDINATOR_POD -- psql -h localhost -U postgres -d interop_db -c "SELECT * from master_add_node('citus-worker-1.citus-worker.default.svc.cluster.local', 5432);"
    
    print_step "Verificando workers registrados..."
    kubectl exec -it $COORDINATOR_POD -- psql -h localhost -U postgres -d interop_db -c "SELECT * FROM master_get_active_worker_nodes();"
    
    # 8. Insertar datos de prueba
    print_step "¿Deseas insertar datos de prueba? (s/n)"
    read -p "> " INSERT_DATA
    
    if [[ $INSERT_DATA == "s" || $INSERT_DATA == "S" ]]; then
        print_step "Copiando datos de prueba..."
        kubectl cp datos_prueba.sql $COORDINATOR_POD:/tmp/datos_prueba.sql
        
        print_step "Insertando datos de prueba..."
        kubectl exec -it $COORDINATOR_POD -- psql -U postgres -d interop_db -f /tmp/datos_prueba.sql
    fi
else
    echo "La base de datos interop_db ya existe ✓"
    print_warning "Para reiniciar desde cero, ejecuta: kubectl exec -it $COORDINATOR_POD -- psql -U postgres -c 'DROP DATABASE interop_db;'"
fi

# 9. Obtener información de conexión
print_step "Obteniendo información de conexión..."
NODE_PORT=$(kubectl get svc citus-coordinator -o jsonpath='{.spec.ports[0].nodePort}')
MINIKUBE_IP=$(minikube ip)

echo ""
echo "=========================================="
echo "  ✓ CONFIGURACIÓN COMPLETADA"
echo "=========================================="
echo ""
echo "Información de conexión:"
echo "  Host: $MINIKUBE_IP"
echo "  Port: $NODE_PORT"
echo "  Database: interop_db"
echo "  User: postgres"
echo "  Password: postgres"
echo ""
echo "Conectar desde tu máquina local:"
echo "  psql -h $MINIKUBE_IP -p $NODE_PORT -U postgres -d interop_db"
echo ""
echo "O usar DBeaver/pgAdmin con:"
echo "  Host: $MINIKUBE_IP"
echo "  Port: $NODE_PORT"
echo ""
echo "Comandos útiles:"
echo "  - Ver pods: kubectl get pods"
echo "  - Logs coordinator: kubectl logs -f $COORDINATOR_POD"
echo "  - Conectar al pod: kubectl exec -it $COORDINATOR_POD -- psql -U postgres -d interop_db"
echo "  - Ver distribución de datos: kubectl exec -it $COORDINATOR_POD -- psql -U postgres -d interop_db -c \"SELECT logicalrelid as table_name, * FROM pg_dist_partition;\""
echo ""
echo "Para detener (sin perder datos):"
echo "  minikube stop"
echo ""
echo "Para reiniciar:"
echo "  minikube start"
echo "  ./setup-citus.sh  (ejecutará este script nuevamente)"
echo ""
echo "=========================================="