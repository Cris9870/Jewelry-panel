#!/bin/bash

# =================================================================
# Script de Despliegue Optimizado para ROOT - Ubuntu 22.04
# Con PDFKit en lugar de Puppeteer
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
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

# Variables de rutas para root
APP_DIR="/opt/jewelry-panel"

print_message "Iniciando instalación optimizada como usuario root..."

# 1. Limpiar instalación anterior si existe
if [ -d "$APP_DIR" ]; then
    print_warning "Eliminando instalación anterior..."
    pm2 delete jewelry-backend 2>/dev/null || true
    rm -rf $APP_DIR
fi

# 2. Instalar dependencias básicas
print_message "1/10 - Instalando herramientas básicas..."
apt update
apt install -y curl wget software-properties-common git nginx

# 3. Instalar Node.js 18 (con verificación)
print_message "2/10 - Instalando Node.js 18..."

# Eliminar versiones antiguas de Node.js si existen
apt remove -y nodejs npm 2>/dev/null || true
apt autoremove -y

# Instalar Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Verificar instalación
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    print_error "Node.js no se instaló correctamente. Instalando desde binarios..."
    cd /tmp
    wget https://nodejs.org/dist/v18.20.0/node-v18.20.0-linux-x64.tar.xz
    tar -xJf node-v18.20.0-linux-x64.tar.xz -C /usr/local --strip-components=1
    ln -sf /usr/local/bin/node /usr/bin/node
    ln -sf /usr/local/bin/npm /usr/bin/npm
    ln -sf /usr/local/bin/npx /usr/bin/npx
fi

print_message "Node.js $(node -v) - npm $(npm -v)"

# Instalar PM2 globalmente
npm install -g pm2

# 4. Instalar y configurar MySQL si no está instalado
print_message "3/10 - Configurando MySQL..."
if ! command -v mysql &> /dev/null; then
    print_message "Instalando MySQL Server..."
    debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
    debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
    apt-get install -y mysql-server
fi

# Configurar base de datos
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS jewelry_panel;
CREATE USER IF NOT EXISTS 'jewelry_user'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON jewelry_panel.* TO 'jewelry_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# 5. Clonar aplicación
print_message "4/10 - Clonando aplicación..."
git clone "$GITHUB_REPO" "$APP_DIR"
cd $APP_DIR

# Actualizar package.json para usar pdfkit en lugar de puppeteer
print_message "Actualizando dependencias para usar PDFKit..."
cd backend
sed -i 's/"puppeteer": "[^"]*"/"pdfkit": "^0.13.0"/' package.json

# 6. Importar esquema
print_message "5/10 - Importando base de datos..."
mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel < database/schema.sql

# 7. Instalar dependencias del backend
print_message "6/10 - Instalando dependencias del backend..."
npm install

# Si hay errores con pdfkit, instalarlo manualmente
if ! npm list pdfkit &>/dev/null; then
    print_warning "Instalando pdfkit manualmente..."
    npm install pdfkit@0.13.0
fi

cd ..

# 8. Instalar dependencias del frontend
print_message "7/10 - Instalando dependencias del frontend..."
cd frontend
npm install
cd ..

# 9. Configurar aplicación
print_message "8/10 - Configurando aplicación..."
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

# 10. Compilar frontend
print_message "9/10 - Compilando frontend..."
cd frontend && npm run build && cd ..

# Crear carpetas necesarias
mkdir -p backend/uploads
chmod 755 backend/uploads

# 11. Configurar PM2
print_message "10/10 - Configurando PM2..."
cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [{
    name: 'jewelry-backend',
    script: './backend/server.js',
    cwd: '$APP_DIR',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: '$APP_DIR/logs/error.log',
    out_file: '$APP_DIR/logs/out.log',
    log_file: '$APP_DIR/logs/combined.log',
    time: true
  }]
};
EOF

# Crear directorio de logs
mkdir -p logs

# Iniciar aplicación
pm2 start ecosystem.config.js
pm2 save
pm2 startup systemd -u root --hp /root | tail -n 1 | bash

# 12. Configurar Nginx
print_message "Configurando Nginx..."
tee /etc/nginx/sites-available/jewelry-panel > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $APP_DIR/frontend/dist;
    index index.html;

    # Logs
    access_log /var/log/nginx/jewelry-access.log;
    error_log /var/log/nginx/jewelry-error.log;

    # Tamaño máximo de archivo para uploads
    client_max_body_size 10M;

    location /uploads {
        alias $APP_DIR/backend/uploads;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

ln -sf /etc/nginx/sites-available/jewelry-panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Probar y reiniciar Nginx
nginx -t
if [ $? -eq 0 ]; then
    systemctl restart nginx
else
    print_error "Error en la configuración de Nginx"
    exit 1
fi

# 13. Configurar firewall
print_message "Configurando firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable || true

# 14. Crear scripts de utilidad
print_message "Creando scripts de utilidad..."

# Script de actualización
cat > /root/update-jewelry.sh <<'SCRIPT'
#!/bin/bash
cd /opt/jewelry-panel
git pull
cd backend && npm install && cd ..
cd frontend && npm install && npm run build && cd ..
pm2 restart jewelry-backend
echo "Actualización completada"
SCRIPT
chmod +x /root/update-jewelry.sh

# Script de backup
cat > /root/backup-jewelry.sh <<'SCRIPT'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/backups"
mkdir -p $BACKUP_DIR

# Backup base de datos
mysqldump -u jewelry_user -p'JewelryPass123!' jewelry_panel > $BACKUP_DIR/db_backup_$DATE.sql

# Backup uploads
tar -czf $BACKUP_DIR/uploads_backup_$DATE.tar.gz /opt/jewelry-panel/backend/uploads

# Eliminar backups antiguos (más de 7 días)
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completado: $DATE"
SCRIPT
chmod +x /root/backup-jewelry.sh

# Script de monitoreo
cat > /root/status-jewelry.sh <<'SCRIPT'
#!/bin/bash
echo "=== Estado de Jewelry Panel ==="
echo "PM2:"
pm2 status
echo ""
echo "Nginx:"
systemctl status nginx --no-pager | head -n 5
echo ""
echo "MySQL:"
systemctl status mysql --no-pager | head -n 5
echo ""
echo "Uso de disco:"
df -h | grep -E "^/dev|Filesystem"
echo ""
echo "Memoria:"
free -h
echo ""
echo "Últimos logs:"
pm2 logs jewelry-backend --lines 10 --nostream
SCRIPT
chmod +x /root/status-jewelry.sh

# 15. Verificación final
print_message "Verificando instalación..."
sleep 3

# Verificar que el backend está corriendo
if pm2 list | grep -q "jewelry-backend.*online"; then
    print_message "✓ Backend corriendo correctamente"
else
    print_error "✗ Backend no está corriendo"
    pm2 logs jewelry-backend --lines 20 --nostream
fi

# Verificar que Nginx está corriendo
if systemctl is-active --quiet nginx; then
    print_message "✓ Nginx corriendo correctamente"
else
    print_error "✗ Nginx no está corriendo"
fi

# Verificar conectividad
if curl -s -o /dev/null -w "%{http_code}" http://localhost/api | grep -q "404"; then
    print_message "✓ API respondiendo"
else
    print_warning "⚠ API no responde correctamente"
fi

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
echo "=========================================="
echo "Scripts disponibles:"
echo "  /root/update-jewelry.sh  - Actualizar aplicación"
echo "  /root/backup-jewelry.sh  - Crear backup"
echo "  /root/status-jewelry.sh  - Ver estado"
echo "=========================================="
echo "Comandos útiles:"
echo "  pm2 logs             - Ver logs en tiempo real"
echo "  pm2 restart all      - Reiniciar aplicación"
echo "  pm2 monit            - Monitor interactivo"
echo "=========================================="
echo
print_warning "IMPORTANTE: Cambia las contraseñas por defecto"
echo