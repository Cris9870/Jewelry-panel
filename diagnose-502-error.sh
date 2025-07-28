#!/bin/bash

echo "=== Diagnosticando Error 502 Bad Gateway ==="
echo ""

cd /opt/jewelry-panel

# 1. Verificar estado de PM2
echo "1. Estado de PM2:"
pm2 status
echo ""

# 2. Ver logs de errores recientes
echo "2. Últimos errores de PM2:"
pm2 logs --err --lines 20 --nostream
echo ""

# 3. Verificar que el backend esté escuchando en el puerto correcto
echo "3. Verificando puerto 5000:"
sudo netstat -tlnp | grep :5000 || echo "   ✗ No hay proceso escuchando en puerto 5000"
echo ""

# 4. Verificar conexión a la base de datos
echo "4. Probando conexión a MySQL:"
cd backend
if [ -f ".env" ]; then
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    DB_USER=$(grep DB_USER .env | cut -d '=' -f2)
    DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
    DB_NAME=$(grep DB_NAME .env | cut -d '=' -f2)
    
    mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -e "SELECT 1" 2>&1 | head -5
else
    echo "   ✗ No se encuentra archivo .env"
fi
echo ""

# 5. Verificar configuración de Nginx
echo "5. Verificando Nginx:"
sudo nginx -t
echo ""

# 6. Intentar iniciar el backend directamente
echo "6. Iniciando backend en modo debug..."
cd /opt/jewelry-panel/backend

# Detener PM2 temporalmente
pm2 stop jewelry-backend 2>/dev/null

# Iniciar directamente para ver errores
echo "   Iniciando server.js directamente (Ctrl+C para detener)..."
timeout 5s node server.js 2>&1 || true

echo ""
echo "=== Soluciones Comunes ==="
echo ""
echo "Si ves 'Error: Cannot find module':"
echo "  cd /opt/jewelry-panel/backend && npm install"
echo ""
echo "Si ves 'EADDRINUSE':"
echo "  sudo lsof -i :5000"
echo "  kill -9 [PID]"
echo ""
echo "Si ves errores de MySQL:"
echo "  Verificar credenciales en backend/.env"
echo ""
echo "Para reiniciar todo:"
echo "  cd /opt/jewelry-panel"
echo "  pm2 delete all"
echo "  pm2 start ecosystem.config.js"
echo "  sudo systemctl restart nginx"