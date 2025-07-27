#!/bin/bash

# =================================================================
# Script de Despliegue CORREGIDO para Ubuntu 22.04
# =================================================================

set -e

# CONFIGURAR ESTAS VARIABLES ANTES DE EJECUTAR
GITHUB_REPO="https://github.com/tu-usuario/jewelry-panel.git"
DOMAIN="192.168.1.100"  # Tu IP o dominio
MYSQL_ROOT_PASSWORD="RootPass123!"
MYSQL_PASSWORD="JewelryPass123!"
JWT_SECRET="tu_jwt_secret_super_largo_y_seguro_minimo_32_caracteres"
ADMIN_PASSWORD="admin123"

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 0. Instalar herramientas básicas
print_message "0/12 - Instalando herramientas básicas..."
sudo apt update
sudo apt install -y curl wget software-properties-common

# 1. Actualizar sistema
print_message "1/12 - Actualizando sistema..."
sudo apt upgrade -y

# 2. Limpiar e instalar Node.js correctamente
print_message "2/12 - Instalando Node.js 18 LTS..."
# Eliminar versiones antiguas
sudo apt remove -y nodejs npm || true
sudo apt autoremove -y

# Instalar Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verificar instalación
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    print_error "Node.js no se instaló correctamente. Usando método alternativo..."
    cd /tmp
    wget https://nodejs.org/dist/v18.20.0/node-v18.20.0-linux-x64.tar.xz
    sudo tar -xJf node-v18.20.0-linux-x64.tar.xz -C /usr/local --strip-components=1
    sudo ln -sf /usr/local/bin/node /usr/bin/node
    sudo ln -sf /usr/local/bin/npm /usr/bin/npm
fi

print_message "Node.js $(node -v) - npm $(npm -v)"

# 3. Instalar MySQL
print_message "3/12 - Instalando MySQL..."
if ! command -v mysql &> /dev/null; then
    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
    sudo apt-get install -y mysql-server
fi

# 4. Instalar otras dependencias
print_message "4/12 - Instalando Nginx, PM2 y Git..."
sudo apt-get install -y nginx git
sudo npm install -g pm2

# 5. Configurar base de datos
print_message "5/12 - Configurando base de datos..."
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF || true
CREATE DATABASE IF NOT EXISTS jewelry_panel;
CREATE USER IF NOT EXISTS 'jewelry_user'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON jewelry_panel.* TO 'jewelry_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# 6. Clonar aplicación
print_message "6/12 - Clonando aplicación..."
# Determinar el directorio home correcto
if [ "$USER" = "root" ]; then
    APP_DIR="/opt/jewelry-panel"
    mkdir -p /opt
else
    APP_DIR="/home/$USER/jewelry-panel"
fi

# Eliminar instalación anterior si existe
[ -d "$APP_DIR" ] && rm -rf "$APP_DIR"

# Clonar en el directorio apropiado
git clone "$GITHUB_REPO" "$APP_DIR"
cd "$APP_DIR"

# 7. Configurar aplicación
print_message "7/12 - Configurando aplicación..."
# Importar esquema
mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel < backend/database/schema.sql || true

# Instalar dependencias
npm install
cd backend && npm install && cd ..
cd frontend && npm install && cd ..

# Variables de entorno
cat > backend/.env <<EOF
PORT=5000
DB_HOST=localhost
DB_USER=jewelry_user
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=jewelry_panel
JWT_SECRET=$JWT_SECRET
NODE_ENV=production
EOF

# 8. Configurar contraseña admin
print_message "8/12 - Configurando usuario admin..."
cd backend
# Instalar bcryptjs si no está instalado
npm install bcryptjs
ADMIN_HASH=$(node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('$ADMIN_PASSWORD', 10));")
mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel -e "UPDATE users SET password = '$ADMIN_HASH' WHERE username = 'admin';"
cd ..

# 9. Compilar frontend
print_message "9/12 - Compilando frontend..."
cd frontend && npm run build && cd ..

# 10. Crear carpetas necesarias
mkdir -p backend/uploads
chmod 755 backend/uploads

# 11. Configurar PM2
print_message "10/12 - Configurando PM2..."
cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [{
    name: 'jewelry-backend',
    script: './backend/server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    }
  }]
};
EOF

pm2 start ecosystem.config.js
pm2 save

# Configurar PM2 startup según el usuario
if [ "$USER" = "root" ]; then
    pm2 startup systemd | tail -n 1 | bash
else
    pm2 startup systemd -u $USER --hp /home/$USER | tail -n 1 | bash
fi

# 12. Configurar Nginx
print_message "11/12 - Configurando Nginx..."

# Usar la ruta correcta según el usuario
if [ "$USER" = "root" ]; then
    NGINX_ROOT="/opt/jewelry-panel/frontend/dist"
    NGINX_UPLOADS="/opt/jewelry-panel/backend/uploads"
else
    NGINX_ROOT="/home/$USER/jewelry-panel/frontend/dist"
    NGINX_UPLOADS="/home/$USER/jewelry-panel/backend/uploads"
fi

sudo tee /etc/nginx/sites-available/jewelry-panel > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $NGINX_ROOT;
    index index.html;

    location /uploads {
        alias $NGINX_UPLOADS;
        expires 1y;
    }

    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/jewelry-panel /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx

# 13. Configurar firewall
print_message "12/12 - Configurando firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable || true

# Información final
echo
echo "=========================================="
echo -e "${GREEN}¡INSTALACIÓN COMPLETADA!${NC}"
echo "=========================================="
echo "URL: http://$DOMAIN"
echo "Usuario: admin"
echo "Contraseña: $ADMIN_PASSWORD"
echo "=========================================="
echo "Verificar estado:"
echo "- PM2: pm2 status"
echo "- Logs: pm2 logs"
echo "- Nginx: sudo systemctl status nginx"
echo "=========================================="