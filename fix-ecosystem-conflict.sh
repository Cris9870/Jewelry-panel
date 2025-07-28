#!/bin/bash

echo "=== Resolviendo Conflicto de ecosystem.config.js ==="
echo ""

cd /opt/jewelry-panel

# 1. Ver el conflicto actual
echo "1. Estado del conflicto:"
cat ecosystem.config.js | head -20

# 2. Hacer backup del archivo con conflicto
echo ""
echo "2. Haciendo backup del archivo con conflicto..."
cp ecosystem.config.js ecosystem.config.js.conflict

# 3. Crear el archivo correcto
echo ""
echo "3. Creando ecosystem.config.js correcto..."
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
    env_production: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: '../logs/err.log',
    out_file: '../logs/out.log',
    log_file: '../logs/combined.log',
    time: true,
    max_memory_restart: '500M',
    watch: false,
    ignore_watch: ['node_modules', 'logs', 'uploads'],
    max_restarts: 10,
    min_uptime: '5s',
    autorestart: true,
    cron_restart: '0 0 * * *',
    kill_timeout: 5000,
    wait_ready: true,
    listen_timeout: 3000
  }]
};
EOF

# 4. Reiniciar PM2
echo ""
echo "4. Reiniciando PM2..."
pm2 delete all 2>/dev/null || true
pm2 start ecosystem.config.js

# 5. Verificar estado
echo ""
echo "5. Verificando estado..."
sleep 3
pm2 status

echo ""
echo "=== Conflicto Resuelto ==="
echo ""
echo "El servidor debería estar funcionando correctamente ahora."
echo "Prueba acceder al panel para verificar que todo funcione."