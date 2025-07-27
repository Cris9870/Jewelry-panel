#!/bin/bash

# =================================================================
# Script de Despliegue Automático para Jewelry Panel en Ubuntu 22.04
# =================================================================

set -e  # Detener si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_message() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

# Variables configurables
DOMAIN=""
MYSQL_ROOT_PASSWORD=""
MYSQL_USER="jewelry_user"
MYSQL_PASSWORD=""
JWT_SECRET=""
ADMIN_PASSWORD=""
INSTALL_SSL="n"
GITHUB_REPO=""

# Función para solicitar información
get_user_input() {
    echo "==================================="
    echo "Configuración de Jewelry Panel"
    echo "==================================="
    
    read -p "Ingrese la URL del repositorio GitHub: " GITHUB_REPO
    read -p "Ingrese el dominio o IP del servidor (ej: 192.168.1.100): " DOMAIN
    read -sp "Ingrese la contraseña root de MySQL (nueva instalación): " MYSQL_ROOT_PASSWORD
    echo
    read -sp "Ingrese la contraseña para el usuario de la aplicación MySQL: " MYSQL_PASSWORD
    echo
    read -sp "Ingrese el JWT secret (mínimo 32 caracteres): " JWT_SECRET
    echo
    read -sp "Ingrese la contraseña para el usuario admin del panel: " ADMIN_PASSWORD
    echo
    read -p "¿Desea instalar certificado SSL? (s/n): " INSTALL_SSL
    
    # Validaciones básicas
    if [ -z "$DOMAIN" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$JWT_SECRET" ] || [ -z "$ADMIN_PASSWORD" ]; then
        print_error "Todos los campos son obligatorios"
        exit 1
    fi
    
    if [ ${#JWT_SECRET} -lt 32 ]; then
        print_error "El JWT secret debe tener al menos 32 caracteres"
        exit 1
    fi
}

# Función para actualizar el sistema
update_system() {
    print_message "Actualizando el sistema..."
    sudo apt update && sudo apt upgrade -y
}

# Función para instalar Node.js
install_nodejs() {
    print_message "Instalando Node.js 18 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    # Verificar instalación
    node_version=$(node -v)
    npm_version=$(npm -v)
    print_message "Node.js instalado: $node_version"
    print_message "NPM instalado: $npm_version"
}

# Función para instalar MySQL
install_mysql() {
    print_message "Instalando MySQL Server..."
    
    # Pre-configurar MySQL para instalación no interactiva
    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
    
    sudo apt-get install -y mysql-server
    
    # Asegurar MySQL
    print_message "Configurando MySQL..."
    sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
}

# Función para instalar otras dependencias
install_dependencies() {
    print_message "Instalando Nginx, PM2 y Git..."
    sudo apt-get install -y nginx git
    sudo npm install -g pm2
}

# Función para configurar la base de datos
setup_database() {
    print_message "Configurando base de datos..."
    
    # Crear base de datos y usuario
    sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS jewelry_panel;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON jewelry_panel.* TO '$MYSQL_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    print_message "Base de datos creada exitosamente"
}

# Función para clonar y configurar la aplicación
setup_application() {
    print_message "Clonando y configurando la aplicación..."
    
    cd /home/$USER
    
    # Clonar repositorio
    if [ -d "jewelry-panel" ]; then
        print_warning "El directorio jewelry-panel ya existe, eliminando..."
        rm -rf jewelry-panel
    fi
    
    git clone "$GITHUB_REPO" jewelry-panel
    cd jewelry-panel
    
    # Importar esquema de base de datos
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" jewelry_panel < backend/database/schema.sql
    
    # Instalar dependencias
    print_message "Instalando dependencias..."
    npm install
    npm run install-all
    
    # Crear archivo de variables de entorno
    cat > backend/.env.production <<EOF
PORT=5000
DB_HOST=localhost
DB_USER=$MYSQL_USER
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=jewelry_panel
JWT_SECRET=$JWT_SECRET
NODE_ENV=production
EOF
    
    # Generar hash de contraseña para admin
    print_message "Configurando usuario admin..."
    cd backend
    ADMIN_HASH=$(node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('$ADMIN_PASSWORD', 10));")
    
    # Actualizar contraseña en la base de datos
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" jewelry_panel <<EOF
UPDATE users SET password = '$ADMIN_HASH' WHERE username = 'admin';
EOF
    
    cd ..
    
    # Compilar frontend
    print_message "Compilando frontend..."
    cd frontend
    npm run build
    cd ..
    
    # Crear carpeta de uploads
    mkdir -p backend/uploads
    chmod 755 backend/uploads
}

# Función para configurar PM2
setup_pm2() {
    print_message "Configurando PM2..."
    
    cd /home/$USER/jewelry-panel
    
    # Crear archivo de configuración PM2
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
    },
    error_file: '/var/log/pm2/jewelry-error.log',
    out_file: '/var/log/pm2/jewelry-out.log',
    log_file: '/var/log/pm2/jewelry-combined.log',
    time: true
  }]
};
EOF
    
    # Crear directorio de logs
    sudo mkdir -p /var/log/pm2
    sudo chown -R $USER:$USER /var/log/pm2
    
    # Iniciar aplicación
    pm2 start ecosystem.config.js --env production
    pm2 save
    pm2 startup systemd -u $USER --hp /home/$USER
    
    # Ejecutar comando de startup
    startup_cmd=$(pm2 startup systemd -u $USER --hp /home/$USER | grep sudo)
    eval $startup_cmd
}

# Función para configurar Nginx
setup_nginx() {
    print_message "Configurando Nginx..."
    
    # Crear configuración del sitio
    sudo tee /etc/nginx/sites-available/jewelry-panel > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    # Frontend
    root /home/$USER/jewelry-panel/frontend/dist;
    index index.html;

    # Logs
    access_log /var/log/nginx/jewelry-access.log;
    error_log /var/log/nginx/jewelry-error.log;

    # Uploads
    location /uploads {
        alias /home/$USER/jewelry-panel/backend/uploads;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # API Backend
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

    # Frontend routes
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF
    
    # Activar sitio
    sudo ln -sf /etc/nginx/sites-available/jewelry-panel /etc/nginx/sites-enabled/
    
    # Desactivar sitio default
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Probar configuración
    sudo nginx -t
    
    # Reiniciar Nginx
    sudo systemctl restart nginx
}

# Función para configurar firewall
setup_firewall() {
    print_message "Configurando firewall..."
    
    sudo ufw allow 22/tcp    # SSH
    sudo ufw allow 80/tcp    # HTTP
    sudo ufw allow 443/tcp   # HTTPS
    sudo ufw --force enable
}

# Función para instalar SSL
install_ssl() {
    if [ "$INSTALL_SSL" = "s" ] || [ "$INSTALL_SSL" = "S" ]; then
        print_message "Instalando certificado SSL..."
        
        sudo apt-get install -y certbot python3-certbot-nginx
        sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@$DOMAIN
    fi
}

# Función para crear scripts de mantenimiento
create_maintenance_scripts() {
    print_message "Creando scripts de mantenimiento..."
    
    # Script de backup
    cat > /home/$USER/backup-jewelry.sh <<EOF
#!/bin/bash
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/$USER/backups"
mkdir -p \$BACKUP_DIR

# Backup base de datos
mysqldump -u $MYSQL_USER -p'$MYSQL_PASSWORD' jewelry_panel > \$BACKUP_DIR/db_backup_\$DATE.sql

# Backup uploads
tar -czf \$BACKUP_DIR/uploads_backup_\$DATE.tar.gz /home/$USER/jewelry-panel/backend/uploads

# Eliminar backups antiguos (más de 7 días)
find \$BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completado: \$DATE"
EOF
    
    chmod +x /home/$USER/backup-jewelry.sh
    
    # Programar backup diario
    (crontab -l 2>/dev/null; echo "0 2 * * * /home/$USER/backup-jewelry.sh") | crontab -
    
    # Script de actualización
    cat > /home/$USER/update-jewelry.sh <<EOF
#!/bin/bash
cd /home/$USER/jewelry-panel
git pull origin main
npm install
npm run install-all
cd frontend && npm run build
pm2 restart jewelry-panel-backend
echo "Actualización completada"
EOF
    
    chmod +x /home/$USER/update-jewelry.sh
}

# Función para instalar herramientas de seguridad adicionales
install_security_tools() {
    print_message "Instalando herramientas de seguridad..."
    
    # Fail2ban
    sudo apt-get install -y fail2ban
    sudo systemctl enable fail2ban
    
    # Actualizaciones automáticas
    sudo apt-get install -y unattended-upgrades
    echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | sudo debconf-set-selections
    sudo dpkg-reconfigure -f noninteractive unattended-upgrades
}

# Función para mostrar información final
show_final_info() {
    echo
    echo "=========================================="
    echo -e "${GREEN}¡Instalación completada exitosamente!${NC}"
    echo "=========================================="
    echo
    echo "Información de acceso:"
    echo "----------------------"
    echo "URL: http://$DOMAIN"
    echo "Usuario: admin"
    echo "Contraseña: [la que configuraste]"
    echo
    echo "Comandos útiles:"
    echo "---------------"
    echo "Ver logs: pm2 logs"
    echo "Estado: pm2 status"
    echo "Reiniciar: pm2 restart jewelry-panel-backend"
    echo "Actualizar: /home/$USER/update-jewelry.sh"
    echo "Backup manual: /home/$USER/backup-jewelry.sh"
    echo
    echo "Archivos importantes:"
    echo "--------------------"
    echo "Configuración: /home/$USER/jewelry-panel/backend/.env.production"
    echo "Logs: /var/log/pm2/"
    echo "Backups: /home/$USER/backups/"
    echo
}

# Función principal
main() {
    clear
    echo "=========================================="
    echo "Script de Instalación - Jewelry Panel"
    echo "=========================================="
    echo
    
    # Verificar que se ejecuta en Ubuntu 22.04
    if ! lsb_release -d | grep -q "Ubuntu 22.04"; then
        print_warning "Este script está diseñado para Ubuntu 22.04"
        read -p "¿Desea continuar de todos modos? (s/n): " continue_anyway
        if [ "$continue_anyway" != "s" ] && [ "$continue_anyway" != "S" ]; then
            exit 0
        fi
    fi
    
    # Obtener entrada del usuario
    get_user_input
    
    # Confirmar instalación
    echo
    echo "Resumen de configuración:"
    echo "------------------------"
    echo "Dominio/IP: $DOMAIN"
    echo "Usuario MySQL: $MYSQL_USER"
    echo "Instalar SSL: $INSTALL_SSL"
    echo
    read -p "¿Desea continuar con la instalación? (s/n): " confirm
    
    if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
        print_message "Instalación cancelada"
        exit 0
    fi
    
    # Ejecutar instalación
    update_system
    install_nodejs
    install_mysql
    install_dependencies
    setup_database
    setup_application
    setup_pm2
    setup_nginx
    setup_firewall
    install_ssl
    create_maintenance_scripts
    install_security_tools
    
    # Mostrar información final
    show_final_info
}

# Ejecutar script principal
main

# Guardar log de instalación
exec > >(tee -a /home/$USER/jewelry-install.log)
exec 2>&1