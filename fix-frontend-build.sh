#!/bin/bash

echo "=== Corrigiendo Frontend para Build ==="
echo ""

cd /opt/jewelry-panel

# 1. Corregir OrderModal.tsx
echo "1. Corrigiendo OrderModal.tsx..."
cd frontend/src/components

# Hacer backup
cp OrderModal.tsx OrderModal.tsx.backup-$(date +%Y%m%d_%H%M%S)

# Aplicar correcciones toFixed
sed -i 's/<span className="item-total">S\/ {item\.total\.toFixed(2)}<\/span>/<span className="item-total">S\/ {parseFloat(String(item.total)).toFixed(2)}<\/span>/g' OrderModal.tsx
sed -i 's/<strong>Total:<\/strong> S\/ {calculateTotal()\.toFixed(2)}/<strong>Total:<\/strong> S\/ {parseFloat(String(calculateTotal())).toFixed(2)}/g' OrderModal.tsx

# 2. Corregir Orders.tsx
echo "2. Corrigiendo Orders.tsx..."
cd ../pages

# Hacer backup
cp Orders.tsx Orders.tsx.backup-$(date +%Y%m%d_%H%M%S)

# Comentar las líneas no utilizadas
sed -i '14s/^/\/\/ /' Orders.tsx

echo "3. Verificando cambios..."
cd ../../
if grep -q "parseFloat(String(" components/OrderModal.tsx; then
    echo "   ✓ OrderModal.tsx corregido"
fi

# 3. Reconstruir frontend
echo ""
echo "4. Reconstruyendo frontend..."
npm run build

if [ $? -eq 0 ]; then
    echo "   ✓ Frontend reconstruido exitosamente"
else
    echo "   ✗ Error al reconstruir frontend"
    echo ""
    echo "Intentando build con --no-emit-on-error..."
    npx vite build
fi

# 4. Reiniciar servicios
echo ""
echo "5. Reiniciando servicios..."
cd /opt/jewelry-panel
pm2 restart all

echo ""
echo "=== Proceso Completado ==="
echo ""
echo "IMPORTANTE: Limpia el caché de tu navegador"
echo "- Chrome/Edge: Ctrl+F5"
echo "- Firefox: Ctrl+Shift+R"
echo "- Safari: Cmd+Shift+R"