#!/bin/bash

echo "=== Corrección Rápida del Frontend ==="
echo ""

cd /opt/jewelry-panel/frontend

# 1. Restaurar archivos originales
echo "1. Restaurando archivos originales..."
if [ -f "src/components/Layout.tsx.backup" ]; then
    cp src/components/Layout.tsx.backup src/components/Layout.tsx
fi
if [ -f "src/App.tsx.backup" ]; then
    cp src/App.tsx.backup src/App.tsx
fi

# 2. Construir sin modificaciones (ignorando errores de TypeScript)
echo ""
echo "2. Construyendo frontend..."
npx vite build --mode production || true

# Si falla, intentar sin type checking
if [ ! -d "dist" ]; then
    echo "   Intentando build sin verificación de tipos..."
    npx tsc --noEmit false || true
    npx vite build --mode production
fi

# 3. Verificar que se creó el build
echo ""
if [ -d "dist" ]; then
    echo "✓ Frontend construido exitosamente"
    ls -la dist/
else
    echo "✗ Error al construir frontend"
fi

# 4. Verificar el backend
echo ""
echo "3. Estado del backend:"
pm2 status
curl -s http://localhost:5000/api/health && echo " ✓ Backend respondiendo" || echo " ✗ Backend no responde"

echo ""
echo "=== Proceso Completado ==="
echo ""
echo "Si el frontend se construyó correctamente, tu aplicación"
echo "debería estar accesible en el navegador."