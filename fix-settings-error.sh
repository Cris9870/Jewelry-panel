#!/bin/bash

echo "=== Corrigiendo Error de Settings ==="
echo ""

cd /opt/jewelry-panel/backend

# 1. Ver qué está mal
echo "1. Verificando el error..."
pm2 logs jewelry-backend --err --lines 20 --nostream

# 2. Probar el servidor directamente
echo ""
echo "2. Probando servidor directamente..."
node server.js 2>&1 | head -20

# 3. Si hay error de sintaxis en server.js, restaurar backup
if [ -f "server.js.backup-settings" ]; then
    echo ""
    echo "3. Restaurando backup de server.js..."
    cp server.js.backup-settings server.js
fi

# 4. Comentar temporalmente la línea de settings
echo ""
echo "4. Deshabilitando temporalmente settings..."
sed -i '/settingsRoutes/s/^/\/\/ /' server.js
sed -i '/\/api\/settings/s/^/\/\/ /' server.js

# 5. Reiniciar
echo ""
echo "5. Reiniciando servidor..."
pm2 restart jewelry-backend

# Esperar
sleep 3

# 6. Verificar estado
echo ""
echo "6. Verificando estado..."
pm2 status

# 7. Probar API
echo ""
echo "7. Probando API..."
curl -s http://localhost:5000/api/health || echo "API no responde"

echo ""
echo "=== Diagnóstico Completado ==="
echo ""
echo "Si el servidor está funcionando ahora, el problema era con settings."
echo "Verificaremos los archivos de settings por separado."