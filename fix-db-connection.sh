#!/bin/bash

echo "=== Corrigiendo Error de Conexión a Base de Datos ==="
echo ""

cd /opt/jewelry-panel/backend

# 1. Verificar archivo .env
echo "1. Verificando archivo .env..."
if [ ! -f ".env" ]; then
    echo "   ✗ Error: No se encuentra archivo .env"
    echo "   Crear archivo .env con las credenciales"
    exit 1
fi

# 2. Mostrar configuración actual (sin contraseña)
echo ""
echo "2. Configuración actual:"
echo "   DB_HOST: $(grep DB_HOST .env | cut -d '=' -f2)"
echo "   DB_USER: $(grep DB_USER .env | cut -d '=' -f2)"
echo "   DB_NAME: $(grep DB_NAME .env | cut -d '=' -f2)"
echo "   DB_PASSWORD: [OCULTO]"

# 3. Verificar que PM2 esté usando las variables
echo ""
echo "3. Verificando PM2..."
pm2 describe jewelry-backend 2>/dev/null | grep -E "(status|NODE_ENV)" || echo "   PM2 no está ejecutando jewelry-backend"

# 4. Reiniciar PM2 con las variables de entorno
echo ""
echo "4. Reiniciando servicios con variables de entorno..."
cd /opt/jewelry-panel

# Detener PM2
pm2 stop all

# Reiniciar con ecosystem.config.js que carga el .env
if [ -f "ecosystem.config.js" ]; then
    # Actualizar ecosystem.config.js para cargar .env
    cat > ecosystem.config.js << 'EOF'
require('dotenv').config({ path: './backend/.env' });

module.exports = {
  apps: [{
    name: 'jewelry-backend',
    script: './backend/server.js',
    instances: 'max',
    exec_mode: 'cluster',
    cwd: './backend',
    env: {
      NODE_ENV: 'production',
      PORT: process.env.PORT || 5000,
      DB_HOST: process.env.DB_HOST || '127.0.0.1',
      DB_USER: process.env.DB_USER,
      DB_PASSWORD: process.env.DB_PASSWORD,
      DB_NAME: process.env.DB_NAME,
      JWT_SECRET: process.env.JWT_SECRET
    },
    error_file: '../logs/err.log',
    out_file: '../logs/out.log',
    log_file: '../logs/combined.log',
    time: true,
    max_memory_restart: '500M',
    watch: false,
    autorestart: true
  }]
};
EOF
    
    pm2 delete all 2>/dev/null || true
    pm2 start ecosystem.config.js
else
    # Usar método alternativo
    cd backend
    pm2 start server.js --name jewelry-backend -i max
fi

# 5. Verificar logs
echo ""
echo "5. Verificando logs..."
pm2 logs jewelry-backend --lines 10 --nostream

echo ""
echo "=== Proceso Completado ==="
echo ""
echo "Si el error persiste, verifica:"
echo "1. Que el archivo backend/.env tenga las credenciales correctas"
echo "2. Que MySQL esté ejecutándose: sudo systemctl status mysql"
echo "3. Que las credenciales sean válidas: mysql -u [usuario] -p"
echo ""
echo "Para ver logs en tiempo real: pm2 logs jewelry-backend"