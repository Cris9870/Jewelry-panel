#!/bin/bash

echo "=== Actualización Simple del Panel de Joyería ==="
echo ""

# Configuración
PROJECT_DIR="/opt/jewelry-panel"

# Verificar directorio
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: El directorio $PROJECT_DIR no existe"
    echo "Primero ejecuta el script de instalación inicial"
    exit 1
fi

cd $PROJECT_DIR

# Verificar proyecto
if [ ! -d ".git" ] || [ ! -d "backend" ] || [ ! -d "frontend" ]; then
    echo "Error: No se encuentra un proyecto válido en $PROJECT_DIR"
    exit 1
fi

# Backup de base de datos
echo "1. Creando backup de la base de datos..."
if [ -f "backend/.env" ]; then
    DB_NAME=$(grep DB_NAME backend/.env | cut -d '=' -f2)
    DB_USER=$(grep DB_USER backend/.env | cut -d '=' -f2)
    DB_PASS=$(grep DB_PASSWORD backend/.env | cut -d '=' -f2)
    DB_HOST=$(grep DB_HOST backend/.env | cut -d '=' -f2)
    
    BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
    mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME > $BACKUP_FILE 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "   ✓ Backup creado: $BACKUP_FILE"
    else
        echo "   ✗ No se pudo crear backup (continuando de todos modos)"
    fi
else
    echo "   ✗ No se encontró archivo .env"
fi

# Actualizar código
echo ""
echo "2. Obteniendo últimos cambios..."
git stash save "Cambios locales antes de actualización"
git pull origin main

if [ $? -ne 0 ]; then
    echo "   ✗ Error al obtener cambios"
    echo "   Intentando resolver..."
    git fetch origin main
    git reset --hard origin/main
fi

# Restaurar cambios locales
git stash pop 2>/dev/null

# Instalar dependencias del backend
echo ""
echo "3. Verificando dependencias del backend..."
cd backend
npm install --production

# Aplicar migraciones
echo ""
echo "4. Aplicando migraciones de base de datos..."
if [ -d "migrations" ] && [ -f "../$BACKUP_FILE" ]; then
    for migration in migrations/*.sql; do
        if [ -f "$migration" ]; then
            echo "   Aplicando: $(basename $migration)"
            mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME < "$migration" 2>/dev/null
        fi
    done
fi

# Instalar dependencias y construir frontend
echo ""
echo "5. Actualizando frontend..."
cd ../frontend
npm install --production
npm run build

if [ $? -ne 0 ]; then
    echo "   ✗ Error al construir frontend"
    exit 1
fi

# Reiniciar servicios
echo ""
echo "6. Reiniciando servicios..."
cd ..
pm2 restart ecosystem.config.js 2>/dev/null || pm2 restart all 2>/dev/null

if [ $? -eq 0 ]; then
    echo "   ✓ Servicios reiniciados"
else
    echo "   ✗ No se pudo reiniciar con PM2"
    echo "   Intenta manualmente: pm2 restart all"
fi

echo ""
echo "=== Actualización completada ==="
echo ""
echo "Verifica tu aplicación en el navegador"
echo ""
echo "Si hay problemas, restaura el backup con:"
echo "mysql -h $DB_HOST -u $DB_USER -p $DB_NAME < $BACKUP_FILE"