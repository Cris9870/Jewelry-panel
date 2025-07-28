#!/bin/bash

echo "=== Actualización Forzada del Panel ==="
echo ""

cd /opt/jewelry-panel

# 1. Guardar el archivo .env
echo "1. Guardando configuración..."
cp backend/.env backend/.env.backup 2>/dev/null

# 2. Resolver conflicto de ecosystem.config.js
echo "2. Resolviendo conflictos..."
rm -f ecosystem.config.js.orig
git reset --hard HEAD

# 3. Actualizar código
echo "3. Actualizando código..."
git fetch origin main
git reset --hard origin/main

# 4. Restaurar .env
echo "4. Restaurando configuración..."
cp backend/.env.backup backend/.env 2>/dev/null

# 5. Instalar dependencias si es necesario
echo "5. Verificando dependencias..."
cd backend
npm install --production
cd ../frontend
npm install

# 6. Construir frontend
echo "6. Construyendo frontend..."
npm run build

# 7. Reiniciar servicios con PM2
echo "7. Reiniciando servicios..."
cd /opt/jewelry-panel
pm2 delete all 2>/dev/null || true

# Crear ecosystem.config.js simple
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

# Crear carpeta de logs
mkdir -p logs

# Iniciar PM2
pm2 start ecosystem.config.js
pm2 save

# 8. Verificar estado
echo ""
echo "8. Estado de los servicios:"
sleep 3
pm2 status

echo ""
echo "=== Actualización Completada ==="
echo ""
echo "Cambios aplicados:"
echo "✓ Mensajes de error de login ahora permanecen visibles"
echo "✓ Corregido error al editar pedidos"
echo "✓ Solucionado problema de estilos en página de Pedidos"
echo ""
echo "Si todo está bien, deberías poder acceder al panel."
echo "Para ver logs: pm2 logs"