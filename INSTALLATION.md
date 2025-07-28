# Q'BellaJoyeria - Guía de Instalación

## Requisitos Previos

- Ubuntu 22.04 o superior
- Node.js 18+ y npm
- MySQL 8.0+
- Nginx
- PM2 (se instala con el script)
- Git

## Instalación Rápida

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/jewelry-panel.git
cd jewelry-panel
```

### 2. Ejecutar el script de instalación

```bash
chmod +x deploy-ubuntu-final.sh
./deploy-ubuntu-final.sh
```

El script te pedirá:
- IP del servidor
- Contraseña para MySQL
- Contraseña para el usuario admin
- Token JWT secreto

### 3. Configuración Manual (si es necesario)

#### Backend (.env)

```env
PORT=5000
DB_HOST=127.0.0.1  # IMPORTANTE: Usar 127.0.0.1, NO localhost
DB_USER=jewelry_user
DB_PASSWORD=tu_contraseña_segura
DB_NAME=jewelry_panel
JWT_SECRET=tu_jwt_secret_minimo_32_caracteres
NODE_ENV=production
```

#### Permisos del directorio uploads

```bash
chmod 755 backend/uploads
chown -R www-data:www-data backend/uploads
```

## Solución de Problemas Comunes

### Error: connect ECONNREFUSED ::1:3306

**Causa**: MySQL intenta conectar por IPv6.

**Solución**: Asegúrate de que `DB_HOST=127.0.0.1` en el archivo `.env`

### Las imágenes no se suben

**Verificar**:
1. Permisos del directorio: `ls -la backend/uploads/`
2. Logs de PM2: `pm2 logs jewelry-backend`
3. Configuración de Nginx para servir `/uploads`

### Error 502 Bad Gateway

**Verificar**:
1. Backend está corriendo: `pm2 list`
2. Puerto 5000 está escuchando: `netstat -tlnp | grep 5000`
3. Logs del backend: `pm2 logs jewelry-backend --lines 50`

### Frontend no compila

**Solución**:
```bash
cd frontend
npm run build
# Si falla, intentar:
npx vite build
```

## Configuración de Producción

### Nginx

El archivo de configuración debe incluir:

```nginx
location /uploads {
    alias /opt/jewelry-panel/backend/uploads;
    expires 30d;
    add_header Cache-Control "public, immutable";
}

location /api {
    proxy_pass http://localhost:5000/api;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
}
```

### PM2

Para gestionar la aplicación:

```bash
# Ver estado
pm2 list

# Ver logs
pm2 logs jewelry-backend

# Reiniciar
pm2 restart jewelry-backend

# Guardar configuración
pm2 save
pm2 startup  # Para inicio automático
```

## Acceso

- URL: `http://tu-servidor-ip`
- Usuario: `admin`
- Contraseña: la que configuraste durante la instalación

## Actualización

Para actualizar la aplicación:

```bash
cd /opt/jewelry-panel
git pull origin main
cd backend && npm install
cd ../frontend && npm install && npm run build
pm2 restart jewelry-backend
```

## Backup

Se recomienda hacer backup de:
- Base de datos: `mysqldump jewelry_panel > backup.sql`
- Imágenes: `tar -czf uploads-backup.tar.gz backend/uploads/`
- Configuración: `cp backend/.env .env.backup`