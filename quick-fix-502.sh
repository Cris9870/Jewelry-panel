#!/bin/bash

echo "=== Corrigiendo Error 502 Rápidamente ==="
echo ""

cd /opt/jewelry-panel

# 1. Detener PM2
echo "1. Deteniendo PM2..."
pm2 delete all 2>/dev/null || true

# 2. Verificar dependencias
echo "2. Verificando dependencias..."
cd backend
if [ ! -d "node_modules" ] || [ ! -f "node_modules/dotenv/lib/main.js" ]; then
    echo "   Instalando dependencias faltantes..."
    npm install
fi

# 3. Crear carpeta de logs si no existe
echo "3. Creando carpeta de logs..."
cd /opt/jewelry-panel
mkdir -p logs

# 4. Iniciar con PM2 en modo fork primero para debug
echo "4. Iniciando en modo debug..."
cd backend
pm2 start server.js --name jewelry-backend

# Esperar 3 segundos
sleep 3

# 5. Ver si hay errores
echo "5. Verificando errores..."
pm2 logs jewelry-backend --lines 20 --nostream

# 6. Si funciona, cambiar a modo cluster
echo ""
echo "6. Si no hay errores, ejecuta:"
echo "   cd /opt/jewelry-panel"
echo "   pm2 delete all"
echo "   pm2 start ecosystem.config.js"
echo ""
echo "O si hay errores de módulos faltantes:"
echo "   cd /opt/jewelry-panel/backend"
echo "   npm install compression express-rate-limit helmet"