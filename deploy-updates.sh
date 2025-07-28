#!/bin/bash

# Verificar que estamos usando bash
if [ -z "$BASH_VERSION" ]; then
    echo "Este script debe ejecutarse con bash, no con sh"
    echo "Usa: bash deploy-updates.sh"
    exit 1
fi

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

# Verificar si el directorio del proyecto existe
if [ ! -d "$PROJECT_DIR" ]; then
    printf "${RED}Error: El directorio $PROJECT_DIR no existe${NC}\n"
    echo "¿Deseas clonar el proyecto ahora? (s/n)"
    read -p "" CLONE_NOW
    
    if [ "$CLONE_NOW" = "s" ] || [ "$CLONE_NOW" = "S" ]; then
        echo "Clonando el proyecto..."
        cd /opt
        git clone $REPO_URL jewelry-panel
        cd $PROJECT_DIR
    else
        exit 1
    fi
fi

# Cambiar al directorio del proyecto
cd $PROJECT_DIR || exit 1

# Verificar que estamos en el directorio correcto
if [ ! -f "package.json" ] || [ ! -d "backend" ] || [ ! -d "frontend" ]; then
    printf "${RED}Error: El directorio no contiene un proyecto válido${NC}\n"
    echo "Contenido del directorio:"
    ls -la
    exit 1
fi

# Función para verificar comandos
check_command() {
    if ! which $1 > /dev/null 2>&1; then
        echo -e "${RED}Error: $1 no está instalado${NC}"
        exit 1
    fi
}

# Verificar dependencias
echo "Verificando dependencias..."
for cmd in git node npm mysql; do
    if which $cmd > /dev/null 2>&1; then
        printf "${GREEN}✓ $cmd está instalado${NC}\n"
    else
        printf "${RED}✗ $cmd no está instalado${NC}\n"
        echo "Por favor instala $cmd antes de continuar"
        exit 1
    fi
done

echo ""
printf "${GREEN}✓ Todas las dependencias están instaladas${NC}\n"
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
    printf "${GREEN}✓ Backup creado: $BACKUP_FILE${NC}\n"
else
    printf "${RED}Error al crear backup. Abortando...${NC}\n"
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
    printf "${YELLOW}Actualizando URL del repositorio remoto...${NC}\n"
    git remote set-url origin $REPO_URL
fi

# Hacer pull de los últimos cambios
git pull origin main

if [ $? -ne 0 ]; then
    printf "${RED}Error al obtener cambios. Verifica tu conexión y permisos${NC}\n"
    echo "Intentando con fetch y merge..."
    git fetch origin main
    git merge origin/main
    if [ $? -ne 0 ]; then
        printf "${RED}No se pudieron obtener los cambios${NC}\n"
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
                printf "${YELLOW}Advertencia: Error al aplicar $migration${NC}\n"
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
    printf "${RED}Error al construir el frontend${NC}\n"
    exit 1
fi

# Volver al directorio raíz
cd ..

# Reiniciar servicios con PM2
echo ""
echo "Reiniciando servicios..."
pm2 restart ecosystem.config.js

if [ $? -eq 0 ]; then
    printf "${GREEN}✓ Servicios reiniciados correctamente${NC}\n"
else
    printf "${YELLOW}Advertencia: No se pudo reiniciar con PM2, intenta reiniciar manualmente${NC}\n"
fi

# Verificar estado de los servicios
echo ""
echo "Estado de los servicios:"
pm2 status

echo ""
printf "${GREEN}=== Actualización completada ===${NC}\n"
echo ""
echo "Cambios importantes aplicados:"
echo "- ✓ PDF mejorado: SKU ahora aparece debajo del nombre del producto"
echo "- ✓ Mensaje de IGV removido de los PDFs"
echo "- ✓ Nueva página de configuración de empresa disponible en /settings"
echo "- ✓ Interfaz completamente traducida al español"
echo "- ✓ Búsqueda mejorada en selección de clientes y productos"
echo ""
printf "${YELLOW}Nota: Si encuentras algún problema, puedes restaurar el backup con:${NC}\n"
echo "mysql -h $DB_HOST -u $DB_USER -p $DB_NAME < $BACKUP_FILE"
echo ""
echo "¡Tu panel está actualizado y listo para usar!"