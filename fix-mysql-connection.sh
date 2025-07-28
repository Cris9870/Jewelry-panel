#!/bin/bash

echo "=== Corrigiendo Conexión MySQL ==="
echo ""

cd /opt/jewelry-panel/backend

# 1. Backup del .env actual
cp .env .env.backup-$(date +%Y%m%d_%H%M%S)

# 2. Asegurar que DB_HOST sea 127.0.0.1
echo "1. Actualizando configuración de base de datos..."
if grep -q "DB_HOST=" .env; then
    sed -i 's/DB_HOST=.*/DB_HOST=127.0.0.1/' .env
else
    echo "DB_HOST=127.0.0.1" >> .env
fi

# 3. Mostrar configuración actual
echo ""
echo "2. Configuración actual:"
grep -E "DB_HOST|DB_USER|DB_NAME|DB_PASSWORD" .env | sed 's/DB_PASSWORD=.*/DB_PASSWORD=***/'

# 4. Verificar conexión MySQL directamente
echo ""
echo "3. Verificando conexión a MySQL..."
DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
DB_USER=$(grep DB_USER .env | cut -d '=' -f2)
DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
DB_NAME=$(grep DB_NAME .env | cut -d '=' -f2)

mysql -h 127.0.0.1 -u $DB_USER -p$DB_PASS -e "SELECT 1" $DB_NAME >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ Conexión exitosa usando 127.0.0.1"
else
    echo "   ✗ Error de conexión. Verificando alternativas..."
    
    # Probar con localhost
    mysql -h localhost -u $DB_USER -p$DB_PASS -e "SELECT 1" $DB_NAME >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✓ Funciona con 'localhost'. Actualizando..."
        sed -i 's/DB_HOST=.*/DB_HOST=localhost/' .env
    else
        echo "   ✗ No se puede conectar a MySQL"
        echo "   Verifica las credenciales y que MySQL esté corriendo"
    fi
fi

# 5. Verificar que MySQL está escuchando en el puerto correcto
echo ""
echo "4. Verificando puerto MySQL:"
netstat -tln | grep 3306 || ss -tln | grep 3306

# 6. Reiniciar el backend
echo ""
echo "5. Reiniciando backend..."
pm2 restart jewelry-backend

# Esperar
sleep 3

# 7. Probar el endpoint
echo ""
echo "6. Probando login..."
RESPONSE=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}')

echo "Respuesta: $RESPONSE"

if echo "$RESPONSE" | grep -q "token"; then
    echo ""
    echo "✓ ¡Login funcionando correctamente!"
else
    echo ""
    echo "✗ Aún hay errores. Revisando logs..."
    pm2 logs jewelry-backend --err --lines 10 --nostream
fi

echo ""
echo "=== Proceso Completado ==="