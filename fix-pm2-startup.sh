#!/bin/bash

echo "=== Configurando PM2 Correctamente ==="
echo ""

cd /opt/jewelry-panel

# 1. Limpiar PM2
echo "1. Limpiando PM2..."
pm2 delete all 2>/dev/null || true
pm2 kill

# 2. Actualizar código
echo ""
echo "2. Actualizando código..."
git pull origin main

# 3. Instalar dependencias si faltan
echo ""
echo "3. Verificando dependencias del backend..."
cd backend
npm install

# 4. Volver al directorio principal
cd /opt/jewelry-panel

# 5. Iniciar PM2 con ecosystem.config.js
echo ""
echo "4. Iniciando PM2 con configuración..."
pm2 start ecosystem.config.js

# 6. Guardar configuración de PM2
echo ""
echo "5. Guardando configuración de PM2..."
pm2 save

# 7. Configurar PM2 para iniciar al arrancar el sistema
echo ""
echo "6. Configurando PM2 para inicio automático..."
pm2 startup systemd -u root --hp /root
pm2 save

# 8. Verificar estado
echo ""
echo "7. Verificando estado..."
sleep 3
pm2 status

# 9. Ver logs
echo ""
echo "8. Últimas líneas de logs:"
pm2 logs --lines 10 --nostream

# 10. Verificar puerto
echo ""
echo "9. Verificando puerto 5000:"
netstat -tlnp | grep :5000

echo ""
echo "=== Proceso Completado ==="
echo ""
echo "Si todo está correcto, deberías ver:"
echo "- PM2 mostrando procesos 'online'"
echo "- Puerto 5000 en uso"
echo ""
echo "Prueba acceder al panel ahora."
echo ""
echo "Para ver logs en tiempo real: pm2 logs"
echo "Para monitorear: pm2 monit"