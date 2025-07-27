#!/bin/bash

# =================================================================
# Script de Despliegue FINAL para Ubuntu 22.04
# Incluye todas las correcciones y mejoras
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
BLUE='\033[0;34m'
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

# Variables de rutas
APP_DIR="/opt/jewelry-panel"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   INSTALACIÓN DE JEWELRY PANEL         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# 1. Limpiar instalación anterior
if [ -d "$APP_DIR" ]; then
    print_warning "Eliminando instalación anterior..."
    pm2 delete all 2>/dev/null || true
    rm -rf $APP_DIR
fi

# 2. Actualizar sistema e instalar dependencias
print_message "1/9 - Actualizando sistema..."
apt update && apt upgrade -y
apt install -y curl wget software-properties-common git nginx mysql-server

# 3. Instalar Node.js 18
print_message "2/9 - Instalando Node.js 18..."
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
fi

print_message "Node.js $(node -v) - npm $(npm -v)"
npm install -g pm2

# 4. Configurar MySQL
print_message "3/9 - Configurando MySQL..."
# Configurar MySQL para IPv4
cat > /etc/mysql/mysql.conf.d/ipv4.cnf <<EOF
[mysqld]
bind-address = 127.0.0.1
EOF

systemctl restart mysql
sleep 3

# Crear base de datos y usuario
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS jewelry_panel;
CREATE USER IF NOT EXISTS 'jewelry_user'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON jewelry_panel.* TO 'jewelry_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# 5. Clonar aplicación
print_message "4/9 - Clonando aplicación..."
git clone "$GITHUB_REPO" "$APP_DIR"
cd $APP_DIR

# 6. Configurar backend
print_message "5/9 - Configurando backend..."
cd backend

# Actualizar package.json para usar pdfkit
sed -i 's/"puppeteer": "[^"]*"/"pdfkit": "^0.13.0"/' package.json 2>/dev/null || true

# Instalar dependencias
npm install
npm install pdfkit@0.13.0 --save

# Crear archivo .env con DB_HOST correcto
cat > .env <<EOF
PORT=5000
DB_HOST=127.0.0.1
DB_USER=jewelry_user
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=jewelry_panel
JWT_SECRET=$JWT_SECRET
NODE_ENV=production
EOF

# Importar esquema
mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel < database/schema.sql

# Configurar contraseña admin
ADMIN_HASH=$(node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('$ADMIN_PASSWORD', 10));")
mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel -e "UPDATE users SET password = '$ADMIN_HASH' WHERE username = 'admin';"

cd ..

# 7. Configurar frontend
print_message "6/9 - Configurando frontend..."
cd frontend

# Actualizar api.ts para usar rutas relativas
cat > src/services/api.ts <<'EOF'
import axios from 'axios';

const api = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
  }
});

api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default api;
EOF

# Actualizar tsconfig.json
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": false,
    "verbatimModuleSyntax": false
  },
  "include": ["src"]
}
EOF

# Instalar dependencias y compilar
npm install
npx vite build

cd ..

# 8. Configurar PM2
print_message "7/9 - Configurando PM2..."
cd backend
cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [{
    name: 'jewelry-backend',
    script: './server.js',
    cwd: '$APP_DIR/backend',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    }
  }]
};
EOF

# Crear carpetas necesarias
mkdir -p uploads
chmod 755 uploads

# Iniciar backend
pm2 start ecosystem.config.js
pm2 save
pm2 startup systemd -u root --hp /root | tail -n 1 | bash
cd ..

# 9. Configurar Nginx
print_message "8/9 - Configurando Nginx..."
cat > /etc/nginx/sites-available/jewelry-panel <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $APP_DIR/frontend/dist;
    index index.html;

    access_log /var/log/nginx/jewelry-access.log;
    error_log /var/log/nginx/jewelry-error.log;

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
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

ln -sf /etc/nginx/sites-available/jewelry-panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# 10. Crear scripts de utilidad
print_message "9/10 - Creando scripts de utilidad..."
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

cat > /root/backup-jewelry.sh <<'SCRIPT'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/backups"
mkdir -p $BACKUP_DIR
mysqldump -u jewelry_user -p'JewelryPass123!' jewelry_panel > $BACKUP_DIR/db_backup_$DATE.sql
tar -czf $BACKUP_DIR/uploads_backup_$DATE.tar.gz /opt/jewelry-panel/backend/uploads
find $BACKUP_DIR -type f -mtime +7 -delete
echo "Backup completado: $DATE"
SCRIPT
chmod +x /root/backup-jewelry.sh

# 11. Verificación final
sleep 5
echo
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${GREEN}¡INSTALACIÓN COMPLETADA!${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo
echo "🌐 URL: http://$DOMAIN"
echo "👤 Usuario: admin"
echo "🔑 Contraseña: $ADMIN_PASSWORD"
echo
echo "📁 Directorio: $APP_DIR"
echo "📋 Comandos útiles:"
echo "   pm2 status          - Ver estado"
echo "   pm2 logs            - Ver logs"
echo "   pm2 restart all     - Reiniciar"
echo
echo "🔧 Scripts disponibles:"
echo "   /root/update-jewelry.sh  - Actualizar"
echo "   /root/backup-jewelry.sh  - Backup"
echo
echo -e "${YELLOW}⚠️  IMPORTANTE: Cambia las contraseñas por defecto${NC}"
echo