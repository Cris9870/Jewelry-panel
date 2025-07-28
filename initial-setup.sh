#!/bin/bash

echo "=== Instalación Inicial del Panel de Joyería ==="
echo "Este script configurará el proyecto por primera vez en tu servidor"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
PROJECT_DIR="/opt/jewelry-panel"
REPO_URL="https://github.com/Cris9870/Jewelry-panel"

# Verificar que somos root o tenemos sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Este script debe ejecutarse como root o con sudo${NC}"
    exit 1
fi

# Función para verificar comandos
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 no está instalado${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 está instalado${NC}"
        return 0
    fi
}

echo "Verificando dependencias del sistema..."
MISSING_DEPS=0

check_command git || MISSING_DEPS=1
check_command node || MISSING_DEPS=1
check_command npm || MISSING_DEPS=1
check_command mysql || MISSING_DEPS=1
check_command nginx || MISSING_DEPS=1
check_command pm2 || MISSING_DEPS=1

if [ $MISSING_DEPS -eq 1 ]; then
    echo ""
    echo -e "${YELLOW}Faltan dependencias. ¿Deseas instalarlas automáticamente? (s/n)${NC}"
    read -p "" INSTALL_DEPS
    
    if [ "$INSTALL_DEPS" = "s" ] || [ "$INSTALL_DEPS" = "S" ]; then
        echo "Instalando dependencias..."
        apt update
        apt install -y git nodejs npm mysql-server nginx
        npm install -g pm2
    else
        echo -e "${RED}No se puede continuar sin las dependencias necesarias${NC}"
        exit 1
    fi
fi

# Crear directorio del proyecto
echo ""
echo "Creando directorio del proyecto..."
mkdir -p $PROJECT_DIR

# Clonar repositorio
echo "Clonando repositorio..."
cd /opt
if [ -d "$PROJECT_DIR/.git" ]; then
    echo -e "${YELLOW}El proyecto ya existe. Actualizando...${NC}"
    cd $PROJECT_DIR
    git pull origin main
else
    rm -rf $PROJECT_DIR
    git clone $REPO_URL jewelry-panel
    cd $PROJECT_DIR
fi

# Configurar permisos
echo ""
echo "Configurando permisos..."
chown -R www-data:www-data $PROJECT_DIR
chmod -R 755 $PROJECT_DIR

# Instalar dependencias
echo ""
echo "Instalando dependencias del backend..."
cd $PROJECT_DIR/backend
npm install

echo ""
echo "Instalando dependencias del frontend..."
cd $PROJECT_DIR/frontend
npm install

# Configurar archivos .env
echo ""
echo -e "${YELLOW}=== Configuración de Variables de Entorno ===${NC}"
echo ""

if [ ! -f "$PROJECT_DIR/backend/.env" ]; then
    echo "Creando archivo .env del backend..."
    cat > $PROJECT_DIR/backend/.env << EOF
# Server
PORT=5000

# Database
DB_HOST=127.0.0.1
DB_USER=jewelry_user
DB_PASSWORD=tu_contraseña_segura
DB_NAME=jewelry_store

# JWT
JWT_SECRET=tu_jwt_secret_muy_seguro_$(openssl rand -hex 32)

# Upload
UPLOAD_DIR=uploads
MAX_FILE_SIZE=5242880
EOF
    
    echo -e "${YELLOW}IMPORTANTE: Edita $PROJECT_DIR/backend/.env con tus credenciales de MySQL${NC}"
fi

if [ ! -f "$PROJECT_DIR/frontend/.env" ]; then
    echo "Creando archivo .env del frontend..."
    cat > $PROJECT_DIR/frontend/.env << EOF
VITE_API_URL=http://localhost:5000/api
EOF
fi

# Crear base de datos
echo ""
echo -e "${YELLOW}=== Configuración de Base de Datos ===${NC}"
read -p "¿Deseas crear la base de datos ahora? (s/n): " CREATE_DB

if [ "$CREATE_DB" = "s" ] || [ "$CREATE_DB" = "S" ]; then
    read -p "Usuario MySQL root password: " -s MYSQL_ROOT_PASS
    echo ""
    
    mysql -u root -p$MYSQL_ROOT_PASS << EOF
CREATE DATABASE IF NOT EXISTS jewelry_store;
CREATE USER IF NOT EXISTS 'jewelry_user'@'localhost' IDENTIFIED BY 'tu_contraseña_segura';
GRANT ALL PRIVILEGES ON jewelry_store.* TO 'jewelry_user'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Ejecutar migraciones
    echo "Ejecutando migraciones..."
    cd $PROJECT_DIR/backend
    for migration in database/schema.sql migrations/*.sql; do
        if [ -f "$migration" ]; then
            echo "Aplicando: $migration"
            mysql -u jewelry_user -p'tu_contraseña_segura' jewelry_store < "$migration"
        fi
    done
fi

# Crear directorios necesarios
echo ""
echo "Creando directorios necesarios..."
mkdir -p $PROJECT_DIR/backend/uploads
chmod 755 $PROJECT_DIR/backend/uploads

# Construir frontend
echo ""
echo "Construyendo frontend..."
cd $PROJECT_DIR/frontend
npm run build

# Configurar PM2
echo ""
echo "Configurando PM2..."
cd $PROJECT_DIR
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Configurar Nginx
echo ""
echo "Configurando Nginx..."
cat > /etc/nginx/sites-available/jewelry-panel << 'EOF'
server {
    listen 80;
    server_name _;

    # Frontend
    location / {
        root /opt/jewelry-panel/frontend/dist;
        try_files $uri $uri/ /index.html;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Uploads
    location /uploads {
        alias /opt/jewelry-panel/backend/uploads;
    }
}
EOF

ln -sf /etc/nginx/sites-available/jewelry-panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo ""
echo -e "${GREEN}=== Instalación Completada ===${NC}"
echo ""
echo "Próximos pasos:"
echo "1. Edita las credenciales de MySQL en: $PROJECT_DIR/backend/.env"
echo "2. Reinicia los servicios: pm2 restart all"
echo "3. Accede a tu aplicación en: http://tu-servidor-ip"
echo ""
echo "Usuario por defecto: admin"
echo "Contraseña por defecto: admin123"
echo ""
echo -e "${YELLOW}¡IMPORTANTE! Cambia la contraseña por defecto después del primer login${NC}"