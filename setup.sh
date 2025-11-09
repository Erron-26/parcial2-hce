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

# 2. Aplicar configuración de almacenamiento persistente
print_step "Aplicando configuración de almacenamiento persistente..."
kubectl apply -f citus-coordinator-persistent.yaml
kubectl apply -f citus-worker-persistent.yaml

# 3. Esperar a que los pods estén listos
print_step "Esperando a que los pods estén listos (esto puede tardar 2-3 minutos)..."
kubectl wait --for=condition=ready pod -l app=citus-coordinator --timeout=300s
kubectl wait --for=condition=ready pod -l app=citus-worker --timeout=300s

echo "Todos los pods están listos ✓"

# 4. Obtener nombres de pods
COORDINATOR_POD=$(kubectl get pods -l app=citus-coordinator -o jsonpath='{.items[0].metadata.name}')
WORKER_0=$(kubectl get pods -l app=citus-worker -o jsonpath='{.items[0].metadata.name}')
WORKER_1=$(kubectl get pods -l app=citus-worker -o jsonpath='{.items[1].metadata.name}')

echo "Pods detectados:"
echo "  - Coordinator: $COORDINATOR_POD"
echo "  - Worker 0: $WORKER_0"
echo "  - Worker 1: $WORKER_1"

# 5. Verificar si la base de datos ya existe
print_step "Verificando si la base de datos existe..."
DB_EXISTS=$(kubectl exec -it $COORDINATOR_POD -- psql -U postgres -lqt | cut -d \| -f 1 | grep -w interop_db | wc -l)

if [ "$DB_EXISTS" -eq 0 ]; then
    print_step "Creando base de datos interop_db..."
    kubectl exec -it $COORDINATOR_POD -- psql -U postgres -c "CREATE DATABASE interop_db;"
    
    # 6. Copiar y ejecutar script de inicialización
    print_step "Copiando script de inicialización al pod..."
    kubectl cp init_fixed.sql $COORDINATOR_POD:/tmp/init.sql
    
    print_step "Ejecutando script de inicialización..."
    kubectl exec -it $COORDINATOR_POD -- psql -U postgres -d interop_db -f /tmp/init.sql
    
    # 7. Configurar workers en Citus
    print_step "Agregando workers al cluster Citus..."
    kubectl exec -it $COORDINATOR_POD -- psql -U postgres -d interop_db -c "SELECT * from citus_add_node('$WORKER_0.citus-worker.default.svc.cluster.local', 5432);"
    kubectl exec -it $COORDINATOR_POD -- psql -U postgres -d interop_db -c "SELECT * from citus_add_node('$WORKER_1.citus-worker.default.svc.cluster.local', 5432);"
    
    print_step "Verificando workers registrados..."
    kubectl exec -it $COORDINATOR_POD -- psql -U postgres -d interop_db -c "SELECT * FROM citus_get_active_worker_nodes();"
    
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
echo "  - Ver distribución de datos: kubectl exec -it $COORDINATOR_POD -- psql -U postgres -d interop_db -c \"SELECT * FROM citus_tables;\""
echo ""
echo "Para detener (sin perder datos):"
echo "  minikube stop"
echo ""
echo "Para reiniciar:"
echo "  minikube start"
echo "  ./setup-citus.sh  (ejecutará este script nuevamente)"
echo ""
echo "=========================================="