#!/bin/bash

# =================================================================
# Script de Despliegue INTERACTIVO para Ubuntu 22.04
# Con todas las correcciones incorporadas
# =================================================================

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Función para solicitar entrada con valor por defecto
prompt_with_default() {
    local prompt=$1
    local default=$2
    local var_name=$3
    
    read -p "$prompt [$default]: " input_value
    if [ -z "$input_value" ]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$input_value'"
    fi
}

# Función para solicitar contraseña
prompt_password() {
    local prompt=$1
    local var_name=$2
    local password=""
    local password_confirm=""
    
    while true; do
        read -sp "$prompt: " password
        echo
        read -sp "Confirmar contraseña: " password_confirm
        echo
        
        if [ "$password" = "$password_confirm" ]; then
            if [ ${#password} -lt 8 ]; then
                print_error "La contraseña debe tener al menos 8 caracteres"
            else
                eval "$var_name='$password'"
                break
            fi
        else
            print_error "Las contraseñas no coinciden"
        fi
    done
}

# Banner
clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                   JEWELRY PANEL INSTALLER                  ║${NC}"
echo -e "${BLUE}║                    Versión Interactiva                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Verificar que se ejecuta en Ubuntu 22.04
print_info "Verificando sistema operativo..."
if ! lsb_release -d 2>/dev/null | grep -q "Ubuntu 22.04"; then
    print_warning "Este script está optimizado para Ubuntu 22.04"
    read -p "¿Desea continuar de todos modos? (s/n): " continue_anyway
    if [ "$continue_anyway" != "s" ] && [ "$continue_anyway" != "S" ]; then
        exit 0
    fi
fi

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then 
    print_error "Este script debe ejecutarse como root"
    exit 1
fi

# Recopilar información
echo -e "\n${CYAN}=== CONFIGURACIÓN DE LA INSTALACIÓN ===${NC}\n"

# GitHub
prompt_with_default "URL del repositorio GitHub" "https://github.com/tu-usuario/jewelry-panel.git" "GITHUB_REPO"

# Dominio/IP
prompt_with_default "Dominio o IP del servidor" "$(hostname -I | awk '{print $1}')" "DOMAIN"

# MySQL
echo -e "\n${CYAN}Configuración de MySQL:${NC}"
existing_mysql=$(systemctl is-active mysql 2>/dev/null || echo "inactive")
if [ "$existing_mysql" = "active" ]; then
    print_info "MySQL ya está instalado y activo"
    prompt_password "Contraseña de root de MySQL existente" "MYSQL_ROOT_PASSWORD"
else
    print_info "MySQL se instalará como parte del proceso"
    prompt_password "Nueva contraseña para root de MySQL" "MYSQL_ROOT_PASSWORD"
fi

prompt_password "Contraseña para el usuario de la aplicación (jewelry_user)" "MYSQL_PASSWORD"

# JWT Secret
echo -e "\n${CYAN}Seguridad:${NC}"
default_jwt=$(openssl rand -base64 32)
prompt_with_default "JWT Secret (mínimo 32 caracteres)" "$default_jwt" "JWT_SECRET"

# Admin
echo -e "\n${CYAN}Usuario administrador:${NC}"
prompt_with_default "Nombre de usuario admin" "admin" "ADMIN_USERNAME"
prompt_password "Contraseña para el usuario admin" "ADMIN_PASSWORD"

# Sin SSL ni Firewall - Usuario lo configurará

# Resumen
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${CYAN}RESUMEN DE CONFIGURACIÓN:${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo "Repositorio: $GITHUB_REPO"
echo "Dominio/IP: $DOMAIN"
echo "Usuario MySQL: jewelry_user"
echo "Usuario Admin: $ADMIN_USERNAME"
echo -e "${BLUE}═══════════════════════════════════════${NC}"

read -p $'\n¿Desea continuar con la instalación? (s/n): ' confirm
if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
    print_info "Instalación cancelada"
    exit 0
fi

# Variables de rutas
APP_DIR="/opt/jewelry-panel"

# Comenzar instalación
echo -e "\n${GREEN}Iniciando instalación...${NC}\n"

# 1. Limpiar instalación anterior
if [ -d "$APP_DIR" ]; then
    print_warning "Se detectó una instalación anterior"
    read -p "¿Desea eliminarla? (s/n): " remove_old
    if [ "$remove_old" = "s" ] || [ "$remove_old" = "S" ]; then
        pm2 delete all 2>/dev/null || true
        rm -rf $APP_DIR
    else
        print_error "No se puede continuar sin eliminar la instalación anterior"
        exit 1
    fi
fi

# 2. Actualizar sistema
print_message "Actualizando sistema..."
apt update && apt upgrade -y

# 3. Instalar dependencias
print_message "Instalando dependencias básicas..."
apt install -y curl wget software-properties-common git nginx

# 4. Instalar MySQL si no está instalado
if [ "$existing_mysql" != "active" ]; then
    print_message "Instalando MySQL..."
    debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
    debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
    apt-get install -y mysql-server
fi

# 5. Instalar Node.js
print_message "Instalando Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

if ! command -v node &> /dev/null; then
    print_error "Error al instalar Node.js, intentando método alternativo..."
    cd /tmp
    wget https://nodejs.org/dist/v18.20.0/node-v18.20.0-linux-x64.tar.xz
    tar -xJf node-v18.20.0-linux-x64.tar.xz -C /usr/local --strip-components=1
    ln -sf /usr/local/bin/node /usr/bin/node
    ln -sf /usr/local/bin/npm /usr/bin/npm
fi

print_info "Node.js $(node -v) - npm $(npm -v)"
npm install -g pm2

# 6. Configurar MySQL para IPv4
print_message "Configurando MySQL..."
cat > /etc/mysql/mysql.conf.d/ipv4.cnf <<EOF
[mysqld]
bind-address = 127.0.0.1
EOF
systemctl restart mysql

# Crear base de datos
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS jewelry_panel;
CREATE USER IF NOT EXISTS 'jewelry_user'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON jewelry_panel.* TO 'jewelry_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# 7. Clonar aplicación
print_message "Clonando aplicación..."
git clone "$GITHUB_REPO" "$APP_DIR"
cd $APP_DIR

# 8. Backend
print_message "Configurando backend..."
cd backend
sed -i 's/"puppeteer": "[^"]*"/"pdfkit": "^0.13.0"/' package.json 2>/dev/null || true
npm install

# Crear .env
cat > .env <<EOF
PORT=5000
DB_HOST=127.0.0.1
DB_USER=jewelry_user
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=jewelry_panel
JWT_SECRET=$JWT_SECRET
NODE_ENV=production
EOF

# Importar DB
mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel < database/schema.sql

# Usuario admin
if [ "$ADMIN_USERNAME" != "admin" ]; then
    mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel -e "UPDATE users SET username = '$ADMIN_USERNAME' WHERE username = 'admin';"
fi
ADMIN_HASH=$(node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('$ADMIN_PASSWORD', 10));")
mysql -u jewelry_user -p"$MYSQL_PASSWORD" jewelry_panel -e "UPDATE users SET password = '$ADMIN_HASH' WHERE username = '$ADMIN_USERNAME';"

cd ..

# 9. Frontend
print_message "Configurando frontend..."
cd frontend

# api.ts con rutas relativas
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
  (error) => Promise.reject(error)
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

# tsconfig simplificado
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

npm install
print_message "Compilando frontend (esto puede tardar unos minutos)..."
npx vite build
cd ..

# 10. PM2
print_message "Configurando PM2..."
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
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    }
  }]
};
EOF

mkdir -p uploads
chmod 755 uploads
pm2 start ecosystem.config.js
pm2 save
pm2 startup systemd -u root --hp /root | tail -n 1 | bash
cd ..

# 11. Nginx
print_message "Configurando Nginx..."
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

# 12. Scripts
print_message "Creando scripts de utilidad..."
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

# 13. Finalización
echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 ¡INSTALACIÓN COMPLETADA!                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${CYAN}Acceso al panel:${NC}"
echo "🌐 URL: http://$DOMAIN"
echo "👤 Usuario: $ADMIN_USERNAME"
echo "🔑 Contraseña: [la que configuraste]"
echo
echo -e "${CYAN}Información del sistema:${NC}"
echo "📁 Directorio: $APP_DIR"
echo "📊 Estado: pm2 status"
echo "📜 Logs: pm2 logs"
echo
echo -e "${CYAN}Scripts disponibles:${NC}"
echo "🔄 Actualizar: /root/update-jewelry.sh"
echo
print_warning "Recuerda cambiar las contraseñas por defecto en producción"
echo