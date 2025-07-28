#!/bin/bash

echo "=== Solucionando PM2 y Dotenv ==="
echo ""

cd /opt/jewelry-panel

# 1. Limpiar archivos locales conflictivos
echo "1. Limpiando archivos locales..."
rm -f ecosystem.config.js
rm -f diagnose-502-error.sh fix-db-connection.sh fix-pm2-startup.sh

# 2. Actualizar código
echo "2. Actualizando código..."
git fetch origin main
git reset --hard origin/main

# 3. Instalar dotenv en el directorio principal para PM2
echo "3. Instalando dotenv para PM2..."
npm install dotenv

# 4. Crear ecosystem.config.js sin require dotenv
echo "4. Creando ecosystem.config.js simplificado..."
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'jewelry-backend',
    script: './server.js',
    cwd: './backend',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: '../logs/err.log',
    out_file: '../logs/out.log',
    log_file: '../logs/combined.log',
    time: true,
    max_memory_restart: '500M',
    watch: false,
    autorestart: true,
    wait_ready: true,
    listen_timeout: 3000
  }]
};
EOF

# 5. Crear carpeta de logs
echo "5. Creando carpeta de logs..."
mkdir -p logs

# 6. Limpiar PM2 completamente
echo "6. Limpiando PM2..."
pm2 delete all 2>/dev/null || true
pm2 kill

# 7. Iniciar PM2
echo "7. Iniciando PM2..."
pm2 start ecosystem.config.js

# 8. Guardar configuración
echo "8. Guardando configuración..."
pm2 save --force

# 9. Verificar estado
echo ""
echo "9. Estado actual:"
sleep 3
pm2 status

# 10. Verificar puerto
echo ""
echo "10. Puerto 5000:"
netstat -tlnp | grep :5000 || echo "Esperando que el servidor inicie..."

# 11. Ver logs
echo ""
echo "11. Logs recientes:"
pm2 logs --lines 15 --nostream

echo ""
echo "=== Proceso Completado ==="
echo ""
echo "Si hay errores de módulos, ejecuta:"
echo "  cd /opt/jewelry-panel/backend"
echo "  npm install compression express-rate-limit helmet"
echo ""
echo "Para ver logs: pm2 logs"