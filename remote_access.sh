#!/usr/bin/env bash

# ==========================================
# CONFIGURACIÓN
# ==========================================
SERVICE_NAME="fastapi-service"
PORT="8000"

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ==========================================
# FUNCIÓN DE LIMPIEZA Y SEGURIDAD (TRAP)
# ==========================================
function cleanup {
    echo -e "\n\n${RED}=============================================${NC}"
    echo -e "${RED}   FINALIZANDO Y ASEGURANDO EL SISTEMA       ${NC}"
    echo -e "${RED}=============================================${NC}"
    
    # 1. Cerrar UFW si se abrió
    if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
        # Solo borra la regla si existe, silenciando errores si no
        sudo ufw delete allow $PORT/tcp > /dev/null 2>&1
        echo -e "${GREEN}[SEGURIDAD] Regla de puerto $PORT eliminada de UFW. \u2713${NC}"
    fi

    # 2. Cerrar Firewalld si se abrió
    if command -v firewall-cmd &> /dev/null && sudo firewall-cmd --state &> /dev/null; then
        sudo firewall-cmd --remove-port=$PORT/tcp --permanent > /dev/null 2>&1
        sudo firewall-cmd --reload > /dev/null 2>&1
        echo -e "${GREEN}[SEGURIDAD] Regla de puerto $PORT eliminada de Firewalld. \u2713${NC}"
    fi

    echo -e "${BLUE}\U0001f44b ¡Sustentación terminada! Tu PC está segura de nuevo.${NC}"
    exit 0
}

# Captura SIGINT (Ctrl+C) y SIGTERM para ejecutar 'cleanup' antes de salir
trap cleanup SIGINT SIGTERM EXIT

# ==========================================
# INICIO DEL SCRIPT
# ==========================================
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}   ACCESO REMOTO SEGURO                      ${NC}"
echo -e "${BLUE}=============================================${NC}"

# 1. INSTALACIÓN DE DEPENDENCIAS (QRENCODE)
if ! command -v qrencode &> /dev/null; then
    echo -e "${YELLOW}[SETUP] Instalando 'qrencode' para el código QR...${NC}"
    if command -v apt &> /dev/null; then sudo apt update -qq && sudo apt install -y qrencode
    elif command -v pacman &> /dev/null; then sudo pacman -Sy --noconfirm qrencode
    elif command -v dnf &> /dev/null; then sudo dnf install -y qrencode
    elif command -v zypper &> /dev/null; then sudo zypper install -y qrencode
    elif command -v apk &> /dev/null; then sudo apk add qrencode
    else echo -e "${RED}[SKIP] No se pudo instalar qrencode automaticamente.${NC}"; fi
fi

# 2. DETECCIÓN DE IP
LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
[ -z "$LOCAL_IP" ] && LOCAL_IP=$(ip addr | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n 1)

if [ -z "$LOCAL_IP" ]; then
    echo -e "${RED}[ERROR] No se detectó IP. ¿Tienes red?${NC}"; exit 1
fi

# 3. APERTURA DE FIREWALL
echo -e "${GREEN}[INFO] Abriendo puerto $PORT temporalmente...${NC}"
if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
    sudo ufw allow $PORT/tcp > /dev/null
    echo -e "${YELLOW}[FIREWALL] Puerto abierto en UFW.${NC}"
elif command -v firewall-cmd &> /dev/null && sudo firewall-cmd --state &> /dev/null; then
    sudo firewall-cmd --add-port=$PORT/tcp --permanent > /dev/null
    sudo firewall-cmd --reload > /dev/null
    echo -e "${YELLOW}[FIREWALL] Puerto abierto en Firewalld.${NC}"
fi

# 4. MOSTRAR QR Y LANZAR
FULL_URL="http://$LOCAL_IP:$PORT/login"
echo -e "\n${GREEN}=============================================${NC}"
echo -e " \U0001f4f1  ${BLUE}ESCANEA PARA ENTRAR AL SISTEMA${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "URL: ${YELLOW}$FULL_URL${NC}"

if command -v qrencode &> /dev/null; then qrencode -t ANSIUTF8 "$FULL_URL"; fi

echo -e "\n${GREEN}[RUNNING] Túnel activo. Presiona ${RED}CTRL+C${GREEN} para cerrar y limpiar.${NC}"

# Bucle principal (Túnel)
while true; do
    # Ejecuta el port-forward, silenciando la salida estándar pero mostrando errores graves
    kubectl port-forward --address 0.0.0.0 service/$SERVICE_NAME $PORT:$PORT > /dev/null 2>&1
    
    # Si kubectl se cae (o se cierra el navegador móvil), espera y reinicia
    sleep 1
done