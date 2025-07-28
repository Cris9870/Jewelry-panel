const express = require('express');
const router = express.Router();

// Middleware simple para verificar token (temporal)
const checkAuth = (req, res, next) => {
  // En producción, esto debería verificar el token JWT
  // Por ahora, verificamos si hay un header de autorización
  const authHeader = req.headers['authorization'];
  if (!authHeader) {
    return res.status(401).json({ error: 'No autorizado' });
  }
  next();
};

// Get company settings
router.get('/company', checkAuth, async (req, res) => {
  try {
    // Verificar si tenemos conexión a DB
    if (global.db) {
      try {
        const [settings] = await global.db.query('SELECT * FROM company_settings LIMIT 1');
        if (settings.length > 0) {
          return res.json(settings[0]);
        }
      } catch (dbError) {
        console.log('DB Error, usando valores por defecto:', dbError.message);
      }
    }
    
    // Valores por defecto
    res.json({
      name: "Q'BellaJoyeria",
      email: 'info@qbellajoyeria.com',
      phone: '(01) 123-4567',
      address: 'Av. Principal 123, Lima',
      logo_url: null
    });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Error al obtener configuración' });
  }
});

// Update company settings
router.put('/company', checkAuth, async (req, res) => {
  try {
    const { name, email, phone, address } = req.body;
    
    // Por ahora solo actualizar si tenemos DB
    if (global.db) {
      try {
        const [existing] = await global.db.query('SELECT * FROM company_settings LIMIT 1');
        
        if (existing.length === 0) {
          await global.db.query(
            'INSERT INTO company_settings (name, email, phone, address) VALUES (?, ?, ?, ?)',
            [name, email, phone, address]
          );
        } else {
          await global.db.query(
            'UPDATE company_settings SET name = ?, email = ?, phone = ?, address = ? WHERE id = ?',
            [name, email, phone, address, existing[0].id]
          );
        }
      } catch (dbError) {
        console.log('DB Error:', dbError.message);
      }
    }
    
    res.json({ message: 'Configuración actualizada exitosamente' });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Error al actualizar' });
  }
});

module.exports = router;