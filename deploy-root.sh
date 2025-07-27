#!/bin/bash

# =================================================================
# Script de Despliegue para ROOT - Ubuntu 22.04
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

# Variables de rutas para root
APP_DIR="/opt/jewelry-panel"

print_message "Iniciando instalación como usuario root..."

# 1. Instalar dependencias básicas
print_message "1/10 - Instalando herramientas básicas..."
apt update
apt install -y curl wget software-properties-common git nginx

# 2. Instalar Node.js 18
print_message "2/10 - Instalando Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
npm install -g pm2

print_message "Node.js $(node -v) - npm $(npm -v)"

# 3. Configurar MySQL
print_message "3/10 - Configurando MySQL..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF || true
CREATE DATABASE IF NOT EXISTS jewelry_panel;
CREATE USER IF NOT EXISTS 'jewelry_user'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON jewelry_panel.* TO 'jewelry_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# 4. Clonar aplicación
print_message "4/10 - Clonando aplicación..."
rm -rf $APP_DIR
git clone "$GITHUB_REPO" "$APP_DIR"
cd $APP_DIR

# 5. Importar esquema
print_message "5/10 - Importando base de datos..."
mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel < backend/database/schema.sql

# 6. Instalar dependencias
print_message "6/10 - Instalando dependencias..."
npm install
cd backend && npm install && cd ..
cd frontend && npm install && cd ..

# 7. Configurar aplicación
print_message "7/10 - Configurando aplicación..."
cat > backend/.env <<EOF
PORT=5000
DB_HOST=localhost
DB_USER=jewelry_user
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=jewelry_panel
JWT_SECRET=$JWT_SECRET
NODE_ENV=production
EOF

# Configurar contraseña admin
cd backend
ADMIN_HASH=$(node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('$ADMIN_PASSWORD', 10));")
mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel -e "UPDATE users SET password = '$ADMIN_HASH' WHERE username = 'admin';"
cd ..

# 8. Compilar frontend
print_message "8/10 - Compilando frontend..."
cd frontend && npm run build && cd ..

# Crear carpetas
mkdir -p backend/uploads
chmod 755 backend/uploads

# 9. Configurar PM2
print_message "9/10 - Configurando PM2..."
cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [{
    name: 'jewelry-backend',
    script: './backend/server.js',
    cwd: '$APP_DIR',
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
pm2 startup systemd | tail -n 1 | bash

# 10. Configurar Nginx
print_message "10/10 - Configurando Nginx..."
tee /etc/nginx/sites-available/jewelry-panel > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $APP_DIR/frontend/dist;
    index index.html;

    location /uploads {
        alias $APP_DIR/backend/uploads;
        expires 1y;
    }

    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_cache_bypass \$http_upgrade;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

ln -sf /etc/nginx/sites-available/jewelry-panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Configurar firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable || true

# Crear script de actualización
cat > /root/update-jewelry.sh <<'SCRIPT'
#!/bin/bash
cd /opt/jewelry-panel
git pull
npm install
cd backend && npm install && cd ..
cd frontend && npm install && npm run build && cd ..
pm2 restart jewelry-backend
echo "Actualización completada"
SCRIPT
chmod +x /root/update-jewelry.sh

# Información final
echo
echo "=========================================="
echo -e "${GREEN}¡INSTALACIÓN COMPLETADA!${NC}"
echo "=========================================="
echo "URL: http://$DOMAIN"
echo "Usuario: admin"
echo "Contraseña: $ADMIN_PASSWORD"
echo "=========================================="
echo "Directorio: $APP_DIR"
echo "Actualizar: /root/update-jewelry.sh"
echo "Logs: pm2 logs"
echo "=========================================="