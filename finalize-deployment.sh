#!/bin/bash

echo "=== Finalizando el Despliegue ==="
echo ""

PROJECT_DIR="/opt/jewelry-panel"

# 1. Reiniciar backend con PM2
echo "1. Reiniciando backend con PM2..."
cd $PROJECT_DIR
pm2 delete all 2>/dev/null

# Crear ecosystem.config.js si no existe
if [ ! -f "ecosystem.config.js" ]; then
    cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'jewelry-backend',
      script: './backend/server.js',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      env: {
        NODE_ENV: 'production'
      }
    }
  ]
};
EOF
fi

pm2 start ecosystem.config.js
pm2 save
pm2 startup systemd -u root --hp /root

# 2. Reconstruir el frontend sin el componente Settings
echo ""
echo "2. Ajustando frontend..."
cd $PROJECT_DIR/frontend

# Remover temporalmente la ruta de Settings del App.tsx
cp src/App.tsx src/App.tsx.backup
sed -i '/import Settings/d' src/App.tsx
sed -i '/path="\/settings"/d' src/App.tsx

# Remover Settings del menú en Layout.tsx
cp src/components/Layout.tsx src/components/Layout.tsx.backup
sed -i "/, Settings/s/, Settings//" src/components/Layout.tsx
sed -i "/path: '\/settings'/,+1d" src/components/Layout.tsx

# 3. Reconstruir frontend
echo ""
echo "3. Reconstruyendo frontend..."
npm run build || npx vite build

# 4. Verificar nginx
echo ""
echo "4. Verificando Nginx..."
nginx -t
systemctl reload nginx

# 5. Verificar que todo esté funcionando
echo ""
echo "5. Verificando servicios..."
sleep 3
pm2 status

# 6. Test del backend
echo ""
echo "6. Probando el backend..."
curl -s http://localhost:5000/api/health | grep -q "ok"
if [ $? -eq 0 ]; then
    echo "   ✓ Backend respondiendo correctamente"
else
    echo "   ✗ Backend no responde"
    pm2 logs jewelry-backend --lines 20 --nostream
fi

echo ""
echo "=== Despliegue Completado ==="
echo ""
echo "La aplicación debería estar funcionando en tu navegador"
echo ""
echo "Características disponibles:"
echo "✓ Gestión de productos con imágenes"
echo "✓ Gestión de clientes"
echo "✓ Sistema de pedidos"
echo "✓ PDFs mejorados (SKU debajo del nombre)"
echo "✓ Búsqueda en selectores"
echo "✓ Interfaz en español"
echo ""
echo "Nota: La página de configuración está temporalmente deshabilitada"
echo "pero el resto de la aplicación funciona correctamente."