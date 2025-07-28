#!/bin/bash

echo "=== Actualización Remota del Panel de Joyería ==="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración predeterminada
PROJECT_DIR="/opt/jewelry-panel"
REPO_URL="https://github.com/Cris9870/Jewelry-panel"

# Solicitar información del servidor
read -p "Ingresa la IP o hostname del servidor: " SERVER_HOST
read -p "Ingresa el usuario SSH (default: root): " SSH_USER
SSH_USER=${SSH_USER:-root}

echo ""
echo "Conectando a $SSH_USER@$SERVER_HOST..."
echo ""

# Crear script temporal que se ejecutará en el servidor
cat << 'REMOTE_SCRIPT' > /tmp/jewelry-update-remote.sh
#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="/opt/jewelry-panel"
REPO_URL="https://github.com/Cris9870/Jewelry-panel"

echo "=== Ejecutando actualización en el servidor ==="
echo ""

# Verificar si el proyecto existe
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}Error: El directorio $PROJECT_DIR no existe${NC}"
    exit 1
fi

cd $PROJECT_DIR

# Verificar si es un repositorio git
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}No se encontró repositorio git. Inicializando...${NC}"
    git init
    git remote add origin $REPO_URL
    git fetch origin main
    git checkout -b main origin/main
fi

# Descargar el script de actualización más reciente
echo "Descargando script de actualización..."
curl -s https://raw.githubusercontent.com/Cris9870/Jewelry-panel/main/deploy-updates.sh -o deploy-updates.sh
chmod +x deploy-updates.sh

# Ejecutar el script de actualización
echo ""
echo "Ejecutando script de actualización..."
./deploy-updates.sh

REMOTE_SCRIPT

# Copiar y ejecutar el script en el servidor remoto
echo "Copiando script al servidor..."
scp /tmp/jewelry-update-remote.sh $SSH_USER@$SERVER_HOST:/tmp/

echo "Ejecutando actualización..."
ssh -t $SSH_USER@$SERVER_HOST 'bash /tmp/jewelry-update-remote.sh'

# Limpiar
rm /tmp/jewelry-update-remote.sh
ssh $SSH_USER@$SERVER_HOST 'rm /tmp/jewelry-update-remote.sh'

echo ""
echo -e "${GREEN}✓ Proceso completado${NC}"
echo ""
echo "Puedes verificar tu aplicación en: http://$SERVER_HOST"