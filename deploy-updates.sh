#!/bin/bash

echo "=== Script de Actualización del Panel de Joyería ==="
echo "Este script actualizará tu aplicación con los últimos cambios"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directorio del proyecto
PROJECT_DIR="/opt/jewelry-panel"
REPO_URL="https://github.com/Cris9870/Jewelry-panel"

# Cambiar al directorio del proyecto
cd $PROJECT_DIR

# Verificar que estamos en el directorio correcto
if [ ! -f "package.json" ] || [ ! -d "backend" ] || [ ! -d "frontend" ]; then
    echo -e "${RED}Error: No se encuentra el proyecto en $PROJECT_DIR${NC}"
    echo "Verificando si el directorio existe..."
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}El directorio $PROJECT_DIR no existe${NC}"
    else
        echo -e "${RED}El directorio existe pero no contiene el proyecto${NC}"
    fi
    exit 1
fi

# Función para verificar comandos
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 no está instalado${NC}"
        exit 1
    fi
}

# Verificar dependencias
echo "Verificando dependencias..."
check_command git
check_command node
check_command npm
check_command mysql

echo -e "${GREEN}✓ Todas las dependencias están instaladas${NC}"
echo ""

# Hacer backup de la base de datos
echo "Creando backup de la base de datos..."
DB_NAME=$(grep DB_NAME backend/.env | cut -d '=' -f2)
DB_USER=$(grep DB_USER backend/.env | cut -d '=' -f2)
DB_PASS=$(grep DB_PASSWORD backend/.env | cut -d '=' -f2)
DB_HOST=$(grep DB_HOST backend/.env | cut -d '=' -f2)

BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Backup creado: $BACKUP_FILE${NC}"
else
    echo -e "${RED}Error al crear backup. Abortando...${NC}"
    exit 1
fi

# Obtener últimos cambios de git
echo ""
echo "Obteniendo últimos cambios del repositorio..."
echo "Repositorio: $REPO_URL"

# Guardar cambios locales si existen (excepto .env)
git stash push -m "Auto stash before update" -- . ':!backend/.env'

# Verificar si tenemos el remote correcto
CURRENT_REMOTE=$(git config --get remote.origin.url)
if [ "$CURRENT_REMOTE" != "$REPO_URL" ] && [ "$CURRENT_REMOTE" != "${REPO_URL}.git" ]; then
    echo -e "${YELLOW}Actualizando URL del repositorio remoto...${NC}"
    git remote set-url origin $REPO_URL
fi

# Hacer pull de los últimos cambios
git pull origin main

if [ $? -ne 0 ]; then
    echo -e "${RED}Error al obtener cambios. Verifica tu conexión y permisos${NC}"
    echo "Intentando con fetch y merge..."
    git fetch origin main
    git merge origin/main
    if [ $? -ne 0 ]; then
        echo -e "${RED}No se pudieron obtener los cambios${NC}"
        exit 1
    fi
fi

# Aplicar cambios locales guardados
git stash pop 2>/dev/null

# Instalar dependencias del backend si hay cambios
echo ""
echo "Verificando dependencias del backend..."
cd backend
if [ package.json -nt node_modules ]; then
    echo "Instalando nuevas dependencias del backend..."
    npm install
fi

# Ejecutar migraciones de base de datos
echo ""
echo "Aplicando migraciones de base de datos..."
if [ -d "migrations" ]; then
    for migration in migrations/*.sql; do
        if [ -f "$migration" ]; then
            echo "Aplicando: $migration"
            mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME < "$migration"
            if [ $? -ne 0 ]; then
                echo -e "${YELLOW}Advertencia: Error al aplicar $migration${NC}"
            fi
        fi
    done
fi

# Volver al directorio raíz
cd ..

# Instalar dependencias del frontend si hay cambios
echo ""
echo "Verificando dependencias del frontend..."
cd frontend
if [ package.json -nt node_modules ]; then
    echo "Instalando nuevas dependencias del frontend..."
    npm install
fi

# Construir el frontend
echo ""
echo "Construyendo el frontend..."
npm run build

if [ $? -ne 0 ]; then
    echo -e "${RED}Error al construir el frontend${NC}"
    exit 1
fi

# Volver al directorio raíz
cd ..

# Reiniciar servicios con PM2
echo ""
echo "Reiniciando servicios..."
pm2 restart ecosystem.config.js

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Servicios reiniciados correctamente${NC}"
else
    echo -e "${YELLOW}Advertencia: No se pudo reiniciar con PM2, intenta reiniciar manualmente${NC}"
fi

# Verificar estado de los servicios
echo ""
echo "Estado de los servicios:"
pm2 status

echo ""
echo -e "${GREEN}=== Actualización completada ===${NC}"
echo ""
echo "Cambios importantes aplicados:"
echo "- ✓ PDF mejorado: SKU ahora aparece debajo del nombre del producto"
echo "- ✓ Mensaje de IGV removido de los PDFs"
echo "- ✓ Nueva página de configuración de empresa disponible en /settings"
echo "- ✓ Interfaz completamente traducida al español"
echo "- ✓ Búsqueda mejorada en selección de clientes y productos"
echo ""
echo -e "${YELLOW}Nota: Si encuentras algún problema, puedes restaurar el backup con:${NC}"
echo "mysql -h $DB_HOST -u $DB_USER -p $DB_NAME < $BACKUP_FILE"
echo ""
echo "¡Tu panel está actualizado y listo para usar!"