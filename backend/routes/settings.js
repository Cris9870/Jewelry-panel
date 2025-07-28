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