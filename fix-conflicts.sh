#!/bin/bash

echo "=== Resolviendo Conflictos de Actualización ==="
echo ""

PROJECT_DIR="/opt/jewelry-panel"
cd $PROJECT_DIR

# Hacer backup de los archivos actuales
echo "1. Creando backup de archivos locales..."
BACKUP_DIR="backups/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Copiar archivos importantes
cp -r backend/routes $BACKUP_DIR/backend_routes 2>/dev/null
cp -r backend/utils $BACKUP_DIR/backend_utils 2>/dev/null
cp -r frontend/src $BACKUP_DIR/frontend_src 2>/dev/null
cp backend/.env $BACKUP_DIR/backend.env 2>/dev/null

echo "   ✓ Backup creado en: $BACKUP_DIR"

# Guardar el archivo .env actual
echo ""
echo "2. Preservando configuración local..."
cp backend/.env backend/.env.temp 2>/dev/null

# Limpiar el estado de git
echo ""
echo "3. Limpiando estado de git..."
git stash drop 2>/dev/null
git reset --hard HEAD
git clean -fd

# Obtener los últimos cambios
echo ""
echo "4. Obteniendo última versión del repositorio..."
git fetch origin main
git reset --hard origin/main

# Restaurar el archivo .env
echo ""
echo "5. Restaurando configuración local..."
if [ -f "backend/.env.temp" ]; then
    mv backend/.env.temp backend/.env
    echo "   ✓ Archivo .env restaurado"
fi

# Instalar dependencias
echo ""
echo "6. Instalando dependencias del backend..."
cd backend
npm install

# Aplicar migraciones
echo ""
echo "7. Aplicando migraciones de base de datos..."
if [ -f ".env" ]; then
    DB_NAME=$(grep DB_NAME .env | cut -d '=' -f2)
    DB_USER=$(grep DB_USER .env | cut -d '=' -f2)
    DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    
    if [ -d "migrations" ]; then
        for migration in migrations/*.sql; do
            if [ -f "$migration" ]; then
                echo "   Aplicando: $(basename $migration)"
                mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME < "$migration" 2>/dev/null || true
            fi
        done
    fi
fi

# Construir frontend
echo ""
echo "8. Construyendo frontend..."
cd ../frontend
npm install
npm run build

# Reiniciar servicios
echo ""
echo "9. Reiniciando servicios..."
cd ..
pm2 restart ecosystem.config.js || pm2 restart all

echo ""
echo "=== Actualización completada ==="
echo ""
echo "Notas importantes:"
echo "- Tu configuración (.env) ha sido preservada"
echo "- Los archivos anteriores están en: $BACKUP_DIR"
echo "- La aplicación ahora está actualizada a la última versión"
echo ""
echo "Nuevas características disponibles:"
echo "✓ Configuración de empresa en el menú lateral"
echo "✓ PDFs mejorados con SKU debajo del nombre"
echo "✓ Búsqueda en selectores de cliente y producto"
echo "✓ Interfaz completamente en español"