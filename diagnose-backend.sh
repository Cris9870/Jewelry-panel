#!/bin/bash

echo "=== Diagnóstico del Backend ==="
echo ""

PROJECT_DIR="/opt/jewelry-panel"
cd $PROJECT_DIR

# 1. Verificar estructura de archivos
echo "1. Verificando estructura de archivos..."
if [ ! -f "backend/server.js" ]; then
    echo "   ✗ No se encuentra backend/server.js"
    exit 1
else
    echo "   ✓ backend/server.js existe"
fi

# 2. Verificar dependencias
echo ""
echo "2. Verificando dependencias del backend..."
cd backend
if [ ! -d "node_modules" ]; then
    echo "   ✗ node_modules no existe. Instalando..."
    npm install
else
    echo "   ✓ node_modules existe"
fi

# 3. Verificar archivos requeridos
echo ""
echo "3. Verificando archivos requeridos..."
REQUIRED_FILES=(
    "routes/auth.js"
    "routes/products.js"
    "routes/customers.js"
    "routes/orders.js"
    "routes/dashboard.js"
    "routes/settings.js"
    "middleware/auth.js"
    "middleware/errorHandler.js"
    "utils/orderUtils.js"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "   ✗ Falta: $file"
    else
        echo "   ✓ $file"
    fi
done

# 4. Verificar conexión a MySQL
echo ""
echo "4. Verificando conexión a MySQL..."
if [ -f ".env" ]; then
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    DB_USER=$(grep DB_USER .env | cut -d '=' -f2)
    DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
    DB_NAME=$(grep DB_NAME .env | cut -d '=' -f2)
    
    mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -e "SELECT 1" $DB_NAME > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✓ Conexión a MySQL exitosa"
    else
        echo "   ✗ No se puede conectar a MySQL"
        echo "   Verificando si la base de datos existe..."
        mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -e "SHOW DATABASES LIKE '$DB_NAME'" 2>&1
    fi
fi

# 5. Limpiar PM2 y reiniciar
echo ""
echo "5. Limpiando PM2 y reiniciando..."
cd $PROJECT_DIR
pm2 delete all 2>/dev/null
pm2 flush  # Limpiar logs antiguos

# 6. Iniciar backend en modo desarrollo para ver errores
echo ""
echo "6. Iniciando backend en modo desarrollo..."
cd backend
pm2 start server.js --name jewelry-backend --no-daemon --log-date-format "YYYY-MM-DD HH:mm:ss" &
PID=$!

# Esperar 5 segundos
sleep 5

# Detener el proceso
kill $PID 2>/dev/null

# 7. Mostrar logs
echo ""
echo "7. Logs del backend:"
pm2 logs jewelry-backend --nostream --lines 50

# 8. Iniciar en modo producción si no hay errores críticos
echo ""
echo "8. Configurando para producción..."
cd $PROJECT_DIR

# Crear ecosystem.config.js correcto
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
      },
      error_file: './logs/backend-error.log',
      out_file: './logs/backend-out.log',
      merge_logs: true,
      time: true
    }
  ]
};
EOF

# Reiniciar con la configuración correcta
pm2 delete all 2>/dev/null
pm2 start ecosystem.config.js

echo ""
echo "=== Diagnóstico Completado ==="
echo ""
echo "Estado actual:"
pm2 status

echo ""
echo "Si aún hay errores, ejecuta:"
echo "cd /opt/jewelry-panel/backend && node server.js"
echo "Esto mostrará el error exacto."