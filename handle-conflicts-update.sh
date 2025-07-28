#!/bin/bash

echo "=== Manejando Conflictos y Actualizando ==="
echo ""

PROJECT_DIR="/opt/jewelry-panel"
cd $PROJECT_DIR

# 1. Hacer backup de archivos locales importantes
echo "1. Haciendo backup de archivos locales..."
BACKUP_DIR="local-backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup de archivos que puedan tener conflictos
if [ -f "backend/middleware/upload.js" ]; then
    cp backend/middleware/upload.js $BACKUP_DIR/
    echo "   Backup: backend/middleware/upload.js"
fi

# Backup del .env siempre
cp backend/.env $BACKUP_DIR/backend.env 2>/dev/null

# 2. Limpiar el estado de git
echo ""
echo "2. Limpiando estado de git..."
# Descartar cambios locales en archivos tracked
git reset --hard HEAD

# Eliminar archivos untracked que causan conflictos
git clean -fd

# 3. Restaurar .env
echo ""
echo "3. Restaurando archivo .env..."
cp $BACKUP_DIR/backend.env backend/.env 2>/dev/null

# 4. Obtener cambios
echo ""
echo "4. Obteniendo últimos cambios..."
git fetch origin main
git reset --hard origin/main

# 5. Verificar si necesitamos crear archivos que no están en el repo
echo ""
echo "5. Verificando archivos necesarios..."

# Si upload.js no existe en el repo pero lo necesitamos
if [ ! -f "backend/middleware/upload.js" ]; then
    echo "   Creando middleware/upload.js..."
    mkdir -p backend/middleware
    cat > backend/middleware/upload.js << 'EOF'
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const uploadDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const fileFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Solo se permiten archivos de imagen'), false);
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024
  }
});

module.exports = upload;
EOF
fi

# 6. Instalar dependencias
echo ""
echo "6. Instalando dependencias..."
cd backend
npm install
cd ../frontend
npm install

# 7. Construir frontend
echo ""
echo "7. Construyendo frontend..."
npm run build

# 8. Aplicar migraciones
echo ""
echo "8. Aplicando migraciones de base de datos..."
cd ../backend
if [ -f ".env" ]; then
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    DB_USER=$(grep DB_USER .env | cut -d '=' -f2)
    DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
    DB_NAME=$(grep DB_NAME .env | cut -d '=' -f2)
    
    for migration in migrations/*.sql; do
        if [ -f "$migration" ]; then
            echo "   Aplicando: $(basename $migration)"
            mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME < "$migration" 2>/dev/null || true
        fi
    done
fi

# 9. Reiniciar servicios
echo ""
echo "9. Reiniciando servicios..."
cd $PROJECT_DIR
pm2 restart ecosystem.config.js || pm2 restart all

echo ""
echo "=== Actualización Completada ==="
echo ""
echo "Archivos locales respaldados en: $BACKUP_DIR"
echo "La aplicación ha sido actualizada a la última versión."
echo ""
echo "Verifica que todo funcione correctamente."