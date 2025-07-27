#!/bin/bash

# =================================================================
# Script Rápido de Despliegue - Sin interacción
# Configurar las variables antes de ejecutar
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
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# 1. Actualizar sistema
print_message "1/12 - Actualizando sistema..."
sudo apt update && sudo apt upgrade -y

# 2. Instalar Node.js
print_message "2/12 - Instalando Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verificar instalación de Node.js
if ! command -v node &> /dev/null; then
    print_message "Node.js no se instaló correctamente. Intentando método alternativo..."
    # Método alternativo usando snap
    sudo snap install node --classic --channel=18
    sudo ln -sf /snap/bin/node /usr/bin/node
    sudo ln -sf /snap/bin/npm /usr/bin/npm
fi

# Verificar versiones
node_version=$(node -v 2>/dev/null || echo "No instalado")
npm_version=$(npm -v 2>/dev/null || echo "No instalado")
print_message "Node.js: $node_version, npm: $npm_version"

# 3. Instalar MySQL (no interactivo)
print_message "3/12 - Instalando MySQL..."
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
sudo apt-get install -y mysql-server

# 4. Instalar Nginx, PM2, Git
print_message "4/12 - Instalando Nginx, PM2 y Git..."
sudo apt-get install -y nginx git

# Esperar a que Node.js esté disponible y recargar PATH
export PATH=$PATH:/usr/bin/node:/usr/bin/npm
source ~/.bashrc

# Verificar que npm está instalado
if ! command -v npm &> /dev/null; then
    print_message "ERROR: npm no se instaló correctamente. Reintentando..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Instalar PM2 globalmente usando la ruta completa de npm
/usr/bin/npm install -g pm2

# 5. Configurar base de datos
print_message "5/12 - Configurando base de datos..."
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS jewelry_panel;
CREATE USER IF NOT EXISTS 'jewelry_user'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON jewelry_panel.* TO 'jewelry_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# 6. Clonar aplicación
print_message "6/12 - Clonando aplicación..."
cd /home/$USER
[ -d "jewelry-panel" ] && rm -rf jewelry-panel
git clone "$GITHUB_REPO" jewelry-panel
cd jewelry-panel

# 7. Importar esquema
mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel < backend/database/schema.sql

# 8. Instalar dependencias y configurar
print_message "7/12 - Instalando dependencias..."
npm install
npm run install-all

# Variables de entorno
cat > backend/.env.production <<EOF
PORT=5000
DB_HOST=localhost
DB_USER=jewelry_user
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=jewelry_panel
JWT_SECRET=$JWT_SECRET
NODE_ENV=production
EOF

# 9. Configurar contraseña admin
print_message "8/12 - Configurando usuario admin..."
cd backend
ADMIN_HASH=$(node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('$ADMIN_PASSWORD', 10));")
mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel -e "UPDATE users SET password = '$ADMIN_HASH' WHERE username = 'admin';"
cd ..

# 10. Compilar frontend
print_message "9/12 - Compilando frontend..."
cd frontend && npm run build && cd ..

# 11. Configurar PM2
print_message "10/12 - Configurando PM2..."
cat > ecosystem.config.js <<'EOF'
module.exports = {
  apps: [{
    name: 'jewelry-panel-backend',
    script: './backend/server.js',
    instances: 2,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env_production: {
      NODE_ENV: 'production',
      PORT: 5000
    }
  }]
};
EOF

pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup systemd -u $USER --hp /home/$USER | grep sudo | bash

# 12. Configurar Nginx
print_message "11/12 - Configurando Nginx..."
sudo tee /etc/nginx/sites-available/jewelry-panel > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /home/$USER/jewelry-panel/frontend/dist;
    index index.html;

    location /uploads {
        alias /home/$USER/jewelry-panel/backend/uploads;
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
sudo systemctl restart nginx

# 13. Configurar firewall
print_message "12/12 - Configurando firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Crear carpetas necesarias
mkdir -p backend/uploads
chmod 755 backend/uploads

# Mostrar información final
echo
echo "=========================================="
echo -e "${GREEN}¡INSTALACIÓN COMPLETADA!${NC}"
echo "=========================================="
echo "URL: http://$DOMAIN"
echo "Usuario: admin"
echo "Contraseña: $ADMIN_PASSWORD"
echo "=========================================="
echo "Comandos útiles:"
echo "- Ver logs: pm2 logs"
echo "- Reiniciar: pm2 restart all"
echo "=========================================="