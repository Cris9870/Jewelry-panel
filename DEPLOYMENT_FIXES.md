# Correcciones Aplicadas Durante el Despliegue

Este documento detalla las correcciones que se aplicaron durante el despliegue en producción.

## 1. Error de Conexión MySQL (IPv6)

### Problema
```
Error: connect ECONNREFUSED ::1:3306
```
MySQL2 intentaba conectarse usando IPv6 (::1) en lugar de IPv4.

### Solución
En `backend/server.js`, se modificó la configuración del pool:
```javascript
const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1', // Forzar IPv4 por defecto
  // ... resto de configuración
});
```

**IMPORTANTE**: En el archivo `.env`, siempre usar:
```
DB_HOST=127.0.0.1
```
NO usar `localhost` ya que puede resolver a IPv6.

## 2. Middleware de Upload Faltante

### Problema
```
Error: Cannot find module '../middleware/upload'
```

### Solución
Se creó el archivo `backend/middleware/upload.js` con la configuración de Multer para manejar uploads de imágenes.

## 3. Settings Route Simplificada

### Problema
El módulo de settings tenía dependencias complejas que causaban errores.

### Solución
Se creó una versión simplificada en `backend/routes/settings.js` que:
- Usa un middleware de autenticación simple
- Maneja errores de base de datos gracefully
- Proporciona valores por defecto si no hay datos

## 4. Migración de Base de Datos

Se agregó la tabla `company_settings`:
```sql
CREATE TABLE IF NOT EXISTS company_settings (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(50),
  address TEXT,
  logo_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

## 5. Scripts de Despliegue

Se crearon varios scripts para facilitar el despliegue:
- `deploy-updates.sh`: Script principal de actualización
- `fix-mysql-connection.sh`: Corrige problemas de conexión IPv6
- `add-settings-feature.sh`: Agrega la funcionalidad de configuración

## Notas Importantes para Futuros Despliegues

1. **Siempre usar `127.0.0.1` en lugar de `localhost`** en la configuración de MySQL
2. **Verificar que todos los archivos de middleware existen** antes de desplegar
3. **Ejecutar las migraciones de base de datos** después de actualizar
4. **Usar PM2 con `--update-env`** al reiniciar para recargar variables de entorno
5. **Hacer backup de la base de datos** antes de cualquier actualización

## Comandos Útiles

```bash
# Verificar el servidor directamente
cd /opt/jewelry-panel/backend
node server.js

# Ver logs de PM2
pm2 logs jewelry-backend --lines 100

# Reiniciar con variables actualizadas
pm2 restart jewelry-backend --update-env

# Verificar conexión MySQL
mysql -h 127.0.0.1 -u jewelry_user -p jewelry_panel -e "SELECT 1"
```