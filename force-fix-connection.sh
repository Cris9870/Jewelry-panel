#!/bin/bash

echo "=== Forzando Corrección de Conexión ==="
echo ""

cd /opt/jewelry-panel/backend

# 1. Matar todos los procesos de PM2
echo "1. Deteniendo PM2 completamente..."
pm2 kill

# 2. Verificar variables de entorno
echo ""
echo "2. Variables actuales en .env:"
grep -E "DB_HOST|DB_USER|DB_NAME" .env

# 3. Crear un script de inicio personalizado
echo ""
echo "3. Creando script de inicio personalizado..."
cat > start-server.sh << 'EOF'
#!/bin/bash
# Cargar variables de entorno explícitamente
export DB_HOST=127.0.0.1
export DB_USER=jewelry_user
export DB_PASSWORD=JewelryPass123!
export DB_NAME=jewelry_panel
export JWT_SECRET=tu_jwt_secret_super_largo_y_seguro_minimo_32_caracteres
export PORT=5000
export NODE_ENV=production

# Iniciar el servidor
node server.js
EOF

chmod +x start-server.sh

# 4. Probar el servidor directamente
echo ""
echo "4. Probando el servidor directamente..."
echo "   (Presiona Ctrl+C después de ver 'Server running on port 5000')"
timeout 5 ./start-server.sh || true

# 5. Crear nueva configuración PM2
echo ""
echo "5. Creando nueva configuración PM2..."
cd /opt/jewelry-panel
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'jewelry-backend',
      script: './backend/server.js',
      cwd: './backend',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      env: {
        NODE_ENV: 'production',
        PORT: 5000,
        DB_HOST: '127.0.0.1',
        DB_USER: 'jewelry_user',
        DB_PASSWORD: 'JewelryPass123!',
        DB_NAME: 'jewelry_panel',
        JWT_SECRET: 'tu_jwt_secret_super_largo_y_seguro_minimo_32_caracteres'
      }
    }
  ]
};
EOF

# 6. Iniciar con PM2
echo ""
echo "6. Iniciando con PM2..."
pm2 start ecosystem.config.js

# 7. Guardar configuración
pm2 save
pm2 startup

# 8. Esperar y verificar
echo ""
echo "7. Esperando a que el servidor inicie..."
sleep 5

# 9. Probar el login
echo ""
echo "8. Probando el login..."
RESPONSE=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' 2>&1)

echo "Respuesta: $RESPONSE"

# 10. Verificar estado
echo ""
echo "9. Estado actual:"
pm2 list
pm2 logs jewelry-backend --lines 10 --nostream

echo ""
echo "=== Proceso Completado ==="
echo ""
echo "Si aún hay errores de conexión, verifica:"
echo "1. Que MySQL esté corriendo: systemctl status mysql"
echo "2. Las credenciales en ecosystem.config.js"
echo "3. Que el usuario MySQL tenga permisos correctos"