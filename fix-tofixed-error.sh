#!/bin/bash

echo "=== Corrigiendo Error toFixed ==="
echo ""

cd /opt/jewelry-panel/frontend/src/components

# 1. Verificar si el archivo existe
if [ ! -f "OrderModal.tsx" ]; then
    echo "Error: No se encuentra OrderModal.tsx"
    exit 1
fi

# 2. Hacer backup
echo "1. Haciendo backup de OrderModal.tsx..."
cp OrderModal.tsx OrderModal.tsx.backup-$(date +%Y%m%d_%H%M%S)

# 3. Aplicar correcciones
echo "2. Aplicando correcciones..."

# Corregir item.total.toFixed
sed -i 's/<span className="item-total">S\/ {item\.total\.toFixed(2)}<\/span>/<span className="item-total">S\/ {parseFloat(String(item.total)).toFixed(2)}<\/span>/g' OrderModal.tsx

# Corregir calculateTotal().toFixed
sed -i 's/<strong>Total:<\/strong> S\/ {calculateTotal()\.toFixed(2)}/<strong>Total:<\/strong> S\/ {parseFloat(String(calculateTotal())).toFixed(2)}/g' OrderModal.tsx

# 4. Verificar cambios
echo "3. Verificando cambios..."
if grep -q "parseFloat(String(" OrderModal.tsx; then
    echo "   ✓ Correcciones aplicadas correctamente"
else
    echo "   ✗ Error al aplicar correcciones"
    exit 1
fi

# 5. Reconstruir frontend
echo ""
echo "4. Reconstruyendo frontend..."
cd /opt/jewelry-panel/frontend
npm run build

if [ $? -eq 0 ]; then
    echo "   ✓ Frontend reconstruido exitosamente"
else
    echo "   ✗ Error al reconstruir frontend"
    exit 1
fi

# 6. Limpiar caché de PM2 si es necesario
echo ""
echo "5. Reiniciando servicios..."
cd /opt/jewelry-panel
pm2 restart all

echo ""
echo "=== Corrección Completada ==="
echo ""
echo "IMPORTANTE: Limpia el caché de tu navegador"
echo "- Chrome/Edge: Ctrl+F5"
echo "- Firefox: Ctrl+Shift+R"
echo "- Safari: Cmd+Shift+R"
echo ""
echo "Luego intenta editar un pedido nuevamente."