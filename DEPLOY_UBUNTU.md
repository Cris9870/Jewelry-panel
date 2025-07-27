# Guía de Despliegue en Ubuntu 22.04

## Preparación del Servidor Ubuntu 22.04

### 1. Actualizar el sistema
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Instalar Node.js (v18 LTS)
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 3. Instalar MySQL Server
```bash
sudo apt install mysql-server -y
sudo mysql_secure_installation
```

### 4. Instalar Nginx
```bash
sudo apt install nginx -y
```

### 5. Instalar PM2 (Process Manager)
```bash
sudo npm install pm2 -g
```

### 6. Instalar Git
```bash
sudo apt install git -y
```

## Configuración de MySQL

### 1. Acceder a MySQL
```bash
sudo mysql
```

### 2. Crear usuario y base de datos
```sql
CREATE DATABASE jewelry_panel;
CREATE USER 'jewelry_user'@'localhost' IDENTIFIED BY 'SecurePassword123!';
GRANT ALL PRIVILEGES ON jewelry_panel.* TO 'jewelry_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 3. Importar esquema
```bash
cd /home/ubuntu
git clone https://github.com/tu-usuario/jewelry-panel.git
cd jewelry-panel
mysql -u jewelry_user -p jewelry_panel < backend/database/schema.sql
```

### 4. Crear contraseña para admin
```bash
cd backend
node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('admin123', 10));"
```

Actualizar en MySQL:
```bash
mysql -u jewelry_user -p jewelry_panel
```
```sql
UPDATE users SET password = '$2a$10$HASH_GENERADO_AQUI' WHERE username = 'admin';
EXIT;
```

## Configuración de la Aplicación

### 1. Instalar dependencias
```bash
cd /home/ubuntu/jewelry-panel
npm install
npm run install-all
```

### 2. Configurar variables de entorno
```bash
cd backend
sudo nano .env.production
```

Contenido de `.env.production`:
```
PORT=5000
DB_HOST=localhost
DB_USER=jewelry_user
DB_PASSWORD=SecurePassword123!
DB_NAME=jewelry_panel
JWT_SECRET=tu_jwt_secret_super_seguro_aqui_cambiar_en_produccion
NODE_ENV=production
```

### 3. Compilar el frontend
```bash
cd /home/ubuntu/jewelry-panel/frontend
npm run build
```

## Configuración de PM2

### 1. Crear archivo de configuración PM2
```bash
cd /home/ubuntu/jewelry-panel
sudo nano ecosystem.config.js
```

Contenido:
```javascript
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
```

### 2. Iniciar la aplicación con PM2
```bash
pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup systemd -u ubuntu --hp /home/ubuntu
```

## Configuración de Nginx

### 1. Crear configuración del sitio
```bash
sudo nano /etc/nginx/sites-available/jewelry-panel
```

Contenido:
```nginx
server {
    listen 80;
    server_name tu-dominio.com;  # Cambiar por tu dominio o IP

    # Frontend
    root /home/ubuntu/jewelry-panel/frontend/dist;
    index index.html;

    # Logs
    access_log /var/log/nginx/jewelry-access.log;
    error_log /var/log/nginx/jewelry-error.log;

    # Uploads
    location /uploads {
        alias /home/ubuntu/jewelry-panel/backend/uploads;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # API Backend
    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Frontend routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

### 2. Activar el sitio
```bash
sudo ln -s /etc/nginx/sites-available/jewelry-panel /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Configuración del Firewall

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS (para futuro)
sudo ufw enable
```

## Permisos y Carpetas

```bash
# Crear carpeta de uploads
mkdir -p /home/ubuntu/jewelry-panel/backend/uploads

# Permisos
sudo chown -R ubuntu:ubuntu /home/ubuntu/jewelry-panel
chmod 755 /home/ubuntu/jewelry-panel/backend/uploads

# Logs PM2
sudo mkdir -p /var/log/pm2
sudo chown -R ubuntu:ubuntu /var/log/pm2
```

## SSL con Let's Encrypt (Opcional pero Recomendado)

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d tu-dominio.com
```

## Scripts de Mantenimiento

### 1. Script de backup
```bash
nano /home/ubuntu/backup-jewelry.sh
```

Contenido:
```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/ubuntu/backups"
mkdir -p $BACKUP_DIR

# Backup base de datos
mysqldump -u jewelry_user -p'SecurePassword123!' jewelry_panel > $BACKUP_DIR/db_backup_$DATE.sql

# Backup uploads
tar -czf $BACKUP_DIR/uploads_backup_$DATE.tar.gz /home/ubuntu/jewelry-panel/backend/uploads

# Eliminar backups antiguos (más de 7 días)
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completado: $DATE"
```

```bash
chmod +x /home/ubuntu/backup-jewelry.sh
```

### 2. Programar backup diario
```bash
crontab -e
```

Agregar:
```
0 2 * * * /home/ubuntu/backup-jewelry.sh
```

## Monitoreo

### 1. Ver logs de PM2
```bash
pm2 logs jewelry-panel-backend
pm2 monit
```

### 2. Ver estado de servicios
```bash
sudo systemctl status nginx
sudo systemctl status mysql
pm2 status
```

### 3. Ver logs de Nginx
```bash
sudo tail -f /var/log/nginx/jewelry-error.log
sudo tail -f /var/log/nginx/jewelry-access.log
```

## Actualización de la Aplicación

```bash
cd /home/ubuntu/jewelry-panel
git pull origin main
npm install
npm run install-all
cd frontend && npm run build
pm2 restart jewelry-panel-backend
```

## Solución de Problemas

### 1. Error de conexión a base de datos
- Verificar credenciales en `.env.production`
- Verificar que MySQL esté corriendo: `sudo systemctl status mysql`

### 2. Error 502 Bad Gateway
- Verificar que PM2 esté corriendo: `pm2 status`
- Revisar logs: `pm2 logs`

### 3. Archivos no se suben
- Verificar permisos: `ls -la /home/ubuntu/jewelry-panel/backend/uploads`
- Verificar espacio en disco: `df -h`

## Seguridad Adicional

### 1. Fail2ban para protección SSH
```bash
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
```

### 2. Actualizaciones automáticas de seguridad
```bash
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure unattended-upgrades
```

### 3. Configurar swap (si tienes poca RAM)
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Acceso a la Aplicación

- **URL**: http://tu-servidor-ip o http://tu-dominio.com
- **Usuario**: admin
- **Contraseña**: La que configuraste en MySQL

¡Tu panel de joyería está listo para usar!