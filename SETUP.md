# Jewelry Panel - Guía de Instalación

## Requisitos Previos
- Node.js v14 o superior
- MySQL 5.7 o superior
- NPM o Yarn

## Instalación Local

### 1. Clonar el repositorio
```bash
git clone https://github.com/tu-usuario/jewelry-panel.git
cd jewelry-panel
```

### 2. Instalar dependencias
```bash
npm install
npm run install-all
```

### 3. Configurar Base de Datos

1. Crear la base de datos en MySQL:
```bash
mysql -u root -p < backend/database/schema.sql
```

2. Configurar las variables de entorno en `backend/.env`:
```
PORT=5000
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=tu_password
DB_NAME=jewelry_panel
JWT_SECRET=tu_clave_secreta_aqui
NODE_ENV=development
```

### 4. Crear usuario administrador

Por defecto, el usuario es `admin`. Para crear la contraseña:

```bash
cd backend
node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('tu_password', 10));"
```

Luego actualizar en la base de datos:
```sql
UPDATE users SET password = 'hash_generado' WHERE username = 'admin';
```

### 5. Ejecutar la aplicación

Desarrollo:
```bash
npm run dev
```

Esto iniciará:
- Backend en http://localhost:5000
- Frontend en http://localhost:5173

## Despliegue en Plesk

### 1. Preparar archivos para producción

1. Compilar el frontend:
```bash
cd frontend
npm run build
```

2. Crear archivo `.htaccess` en la raíz:
```apache
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase /
  
  # API Backend
  RewriteRule ^api/(.*)$ http://localhost:5000/api/$1 [P,L]
  
  # Frontend
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteRule . /index.html [L]
</IfModule>
```

### 2. Estructura de archivos en Plesk

```
/httpdocs
  ├── index.html (desde frontend/dist)
  ├── assets/ (desde frontend/dist)
  ├── .htaccess
  ├── backend/
  │   ├── server.js
  │   ├── routes/
  │   ├── middleware/
  │   ├── utils/
  │   └── uploads/
  └── node_modules/
```

### 3. Configuración en Plesk

1. **Node.js Application**:
   - Document Root: `/httpdocs`
   - Application Mode: `production`
   - Application URL: `/`
   - Application Startup File: `backend/server.js`

2. **Variables de entorno** (en Plesk Node.js settings):
   ```
   NODE_ENV=production
   DB_HOST=localhost
   DB_USER=tu_usuario_db
   DB_PASSWORD=tu_password_db
   DB_NAME=jewelry_panel
   JWT_SECRET=clave_secreta_produccion
   ```

3. **Base de datos MySQL**:
   - Crear base de datos desde Plesk
   - Importar `backend/database/schema.sql`
   - Actualizar credenciales en variables de entorno

4. **Permisos de carpetas**:
   ```bash
   chmod 755 /httpdocs/backend/uploads
   ```

### 4. Script de despliegue

Crear `deploy.sh`:
```bash
#!/bin/bash
# Compilar frontend
cd frontend
npm run build

# Copiar archivos
cp -r dist/* ../httpdocs/
cp -r ../backend ../httpdocs/

# Instalar dependencias de producción
cd ../httpdocs
npm install --production

echo "Despliegue completado"
```

## Mantenimiento

### Backup de base de datos
```bash
mysqldump -u usuario -p jewelry_panel > backup_$(date +%Y%m%d).sql
```

### Logs
Los logs se encuentran en:
- Plesk: `/var/www/vhosts/tu-dominio/logs/`
- Aplicación: Configurar winston o similar para producción

## Seguridad

1. Cambiar `JWT_SECRET` en producción
2. Configurar HTTPS en Plesk
3. Limitar acceso a carpeta uploads
4. Configurar CORS para tu dominio específico
5. Habilitar rate limiting en producción

## Soporte

Para problemas o consultas, revisar:
- Logs de Plesk
- Console del navegador
- Network tab para errores de API