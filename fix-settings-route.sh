#!/bin/bash

echo "=== Corrigiendo rutas de settings ==="
echo ""

cd /opt/jewelry-panel/backend

# 1. Verificar si existe el archivo auth.js en middleware
echo "1. Verificando middleware de autenticación..."
if [ ! -f "middleware/auth.js" ]; then
    echo "   Creando middleware/auth.js..."
    cat > middleware/auth.js << 'EOF'
const jwt = require('jsonwebtoken');

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token no proporcionado' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'default_secret', (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Token inválido' });
    }
    req.user = user;
    next();
  });
};

module.exports = { authenticateToken };
EOF
fi

# 2. Corregir el archivo routes/settings.js
echo ""
echo "2. Corrigiendo routes/settings.js..."
cat > routes/settings.js << 'EOF'
const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const upload = require('../middleware/upload');
const fs = require('fs').promises;
const path = require('path');

// Get company settings
router.get('/company', authenticateToken, async (req, res) => {
  try {
    const [settings] = await db.query('SELECT * FROM company_settings LIMIT 1');
    
    if (settings.length === 0) {
      // Return default settings if none exist
      return res.json({
        name: "Q'BellaJoyeria",
        email: 'info@qbellajoyeria.com',
        phone: '(01) 123-4567',
        address: 'Av. Principal 123, Lima',
        logo_url: null
      });
    }
    
    res.json(settings[0]);
  } catch (error) {
    console.error('Error fetching company settings:', error);
    res.status(500).json({ error: 'Error al obtener la configuración' });
  }
});

// Update company settings
router.put('/company', authenticateToken, upload.single('logo'), async (req, res) => {
  try {
    const { name, email, phone, address } = req.body;
    let logo_url = null;
    
    // Check if settings exist
    const [existing] = await db.query('SELECT * FROM company_settings LIMIT 1');
    
    if (req.file) {
      logo_url = `/uploads/${req.file.filename}`;
      
      // Delete old logo if exists
      if (existing.length > 0 && existing[0].logo_url) {
        const oldLogoPath = path.join(__dirname, '..', existing[0].logo_url);
        try {
          await fs.unlink(oldLogoPath);
        } catch (err) {
          console.error('Error deleting old logo:', err);
        }
      }
    } else if (existing.length > 0) {
      logo_url = existing[0].logo_url;
    }
    
    if (existing.length === 0) {
      // Insert new settings
      await db.query(
        'INSERT INTO company_settings (name, email, phone, address, logo_url) VALUES (?, ?, ?, ?, ?)',
        [name, email, phone, address, logo_url]
      );
    } else {
      // Update existing settings
      await db.query(
        'UPDATE company_settings SET name = ?, email = ?, phone = ?, address = ?, logo_url = ? WHERE id = ?',
        [name, email, phone, address, logo_url, existing[0].id]
      );
    }
    
    res.json({ message: 'Configuración actualizada exitosamente' });
  } catch (error) {
    console.error('Error updating company settings:', error);
    res.status(500).json({ error: 'Error al actualizar la configuración' });
  }
});

module.exports = router;
EOF

# 3. Verificar que errorHandler existe
echo ""
echo "3. Verificando middleware/errorHandler.js..."
if [ ! -f "middleware/errorHandler.js" ]; then
    echo "   Creando middleware/errorHandler.js..."
    cat > middleware/errorHandler.js << 'EOF'
const errorHandler = (err, req, res, next) => {
  console.error(err.stack);
  
  if (err.name === 'ValidationError') {
    return res.status(400).json({ error: err.message });
  }
  
  if (err.name === 'UnauthorizedError') {
    return res.status(401).json({ error: 'No autorizado' });
  }
  
  res.status(500).json({ error: 'Error interno del servidor' });
};

module.exports = { errorHandler };
EOF
fi

# 4. Instalar dependencias necesarias
echo ""
echo "4. Verificando dependencias..."
npm install jsonwebtoken multer

# 5. Reiniciar el backend
echo ""
echo "5. Reiniciando backend..."
pm2 restart jewelry-backend

echo ""
echo "✓ Correcciones aplicadas"
echo ""
echo "Verificando estado..."
sleep 3
pm2 status

# 6. Verificar logs
echo ""
echo "Últimos logs:"
pm2 logs jewelry-backend --lines 20 --nostream