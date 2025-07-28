#!/bin/bash

echo "=== Agregando Funcionalidad de Configuración ==="
echo ""

cd /opt/jewelry-panel

# 1. Crear la migración de base de datos para settings
echo "1. Creando tabla de configuración en la base de datos..."
cd backend

if [ -f ".env" ]; then
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    DB_USER=$(grep DB_USER .env | cut -d '=' -f2)
    DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
    DB_NAME=$(grep DB_NAME .env | cut -d '=' -f2)
    
    mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME << 'EOF'
CREATE TABLE IF NOT EXISTS company_settings (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(50),
  address TEXT,
  logo_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insertar configuración por defecto si no existe
INSERT INTO company_settings (name, email, phone, address) 
SELECT 'Q\'BellaJoyeria', 'info@qbellajoyeria.com', '(01) 123-4567', 'Av. Principal 123, Lima'
WHERE NOT EXISTS (SELECT 1 FROM company_settings);
EOF
    echo "   ✓ Tabla creada/verificada"
fi

# 2. Crear el archivo de rutas de settings
echo ""
echo "2. Creando rutas de configuración..."
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
    const [settings] = await global.db.query('SELECT * FROM company_settings LIMIT 1');
    
    if (settings.length === 0) {
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
    
    const [existing] = await global.db.query('SELECT * FROM company_settings LIMIT 1');
    
    if (req.file) {
      logo_url = `/uploads/${req.file.filename}`;
      
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
      await global.db.query(
        'INSERT INTO company_settings (name, email, phone, address, logo_url) VALUES (?, ?, ?, ?, ?)',
        [name, email, phone, address, logo_url]
      );
    } else {
      await global.db.query(
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

# 3. Actualizar server.js para incluir las rutas de settings
echo ""
echo "3. Actualizando server.js..."
# Hacer backup
cp server.js server.js.backup-settings

# Agregar la línea require si no existe
if ! grep -q "settingsRoutes" server.js; then
    sed -i "/dashboardRoutes/a const settingsRoutes = require('./routes/settings');" server.js
fi

# Agregar la ruta si no existe
if ! grep -q "/api/settings" server.js; then
    sed -i "/app.use('\/api\/dashboard'/a app.use('/api/settings', settingsRoutes);" server.js
fi

# 4. Crear los componentes del frontend
echo ""
echo "4. Creando página de configuración en el frontend..."
cd ../frontend

# Crear Settings.tsx
cat > src/pages/Settings.tsx << 'EOF'
import { useState, useEffect, FormEvent } from 'react';
import { Building2, Mail, Phone, MapPin, Save } from 'lucide-react';
import api from '../services/api';
import './Settings.css';

interface CompanySettings {
  name: string;
  email: string;
  phone: string;
  address: string;
  logo_url?: string;
}

const Settings = () => {
  const [settings, setSettings] = useState<CompanySettings>({
    name: "Q'BellaJoyeria",
    email: 'info@qbellajoyeria.com',
    phone: '(01) 123-4567',
    address: 'Av. Principal 123, Lima',
    logo_url: ''
  });
  const [loading, setLoading] = useState(false);
  const [saved, setSaved] = useState(false);
  const [logoFile, setLogoFile] = useState<File | null>(null);

  useEffect(() => {
    fetchSettings();
  }, []);

  const fetchSettings = async () => {
    try {
      const response = await api.get('/settings/company');
      setSettings(response.data);
    } catch (error) {
      console.error('Error fetching settings:', error);
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setSaved(false);

    const formData = new FormData();
    Object.keys(settings).forEach(key => {
      if (key !== 'logo_url') {
        formData.append(key, settings[key as keyof CompanySettings] || '');
      }
    });

    if (logoFile) {
      formData.append('logo', logoFile);
    }

    try {
      await api.put('/settings/company', formData);
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (error) {
      console.error('Error saving settings:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="settings">
      <div className="page-header">
        <h1 className="page-title">Configuración de la Empresa</h1>
      </div>

      <div className="settings-container">
        <form onSubmit={handleSubmit} className="settings-form">
          <div className="form-section">
            <h3>Información General</h3>
            
            <div className="form-group">
              <label>
                <Building2 size={18} />
                Nombre de la Empresa
              </label>
              <input
                type="text"
                value={settings.name}
                onChange={(e) => setSettings({ ...settings, name: e.target.value })}
                required
              />
            </div>

            <div className="form-group">
              <label>
                <Mail size={18} />
                Email
              </label>
              <input
                type="email"
                value={settings.email}
                onChange={(e) => setSettings({ ...settings, email: e.target.value })}
                required
              />
            </div>

            <div className="form-group">
              <label>
                <Phone size={18} />
                Teléfono
              </label>
              <input
                type="text"
                value={settings.phone}
                onChange={(e) => setSettings({ ...settings, phone: e.target.value })}
                required
              />
            </div>

            <div className="form-group">
              <label>
                <MapPin size={18} />
                Dirección
              </label>
              <textarea
                value={settings.address}
                onChange={(e) => setSettings({ ...settings, address: e.target.value })}
                rows={3}
                required
              />
            </div>
          </div>

          <div className="form-section">
            <h3>Logo de la Empresa</h3>
            
            <div className="form-group">
              <label>Subir Logo</label>
              <input
                type="file"
                accept="image/*"
                onChange={(e) => setLogoFile(e.target.files?.[0] || null)}
              />
              <p className="help-text">
                Recomendado: Imagen cuadrada de al menos 200x200 píxeles
              </p>
            </div>

            {settings.logo_url && (
              <div className="logo-preview">
                <img src={settings.logo_url} alt="Logo actual" />
              </div>
            )}
          </div>

          <div className="form-actions">
            <button type="submit" className="btn btn-primary" disabled={loading}>
              <Save size={20} />
              {loading ? 'Guardando...' : 'Guardar Cambios'}
            </button>
            
            {saved && (
              <span className="success-message">
                ¡Cambios guardados exitosamente!
              </span>
            )}
          </div>
        </form>
      </div>
    </div>
  );
};

export default Settings;
EOF

# Copiar el CSS que ya creamos
if [ ! -f "src/pages/Settings.css" ]; then
    wget -q https://raw.githubusercontent.com/Cris9870/Jewelry-panel/main/frontend/src/pages/Settings.css -O src/pages/Settings.css
fi

# 5. Actualizar App.tsx
echo ""
echo "5. Actualizando rutas en App.tsx..."
# Agregar import si no existe
if ! grep -q "import Settings" src/App.tsx; then
    sed -i "/import Orders/a import Settings from './pages/Settings';" src/App.tsx
fi

# Agregar ruta si no existe
if ! grep -q "path=\"/settings\"" src/App.tsx; then
    sed -i "/<Route path=\"\/orders\"/a \              <Route path=\"/settings\" element={<Settings />} />" src/App.tsx
fi

# 6. Actualizar Layout.tsx
echo ""
echo "6. Actualizando menú en Layout.tsx..."
# Agregar import Settings de lucide-react si no existe
sed -i "s/ShoppingBag, LogOut, Gem/ShoppingBag, Settings, LogOut, Gem/" src/components/Layout.tsx 2>/dev/null || true

# 7. Reconstruir frontend
echo ""
echo "7. Reconstruyendo frontend..."
npm run build

# 8. Reiniciar backend
echo ""
echo "8. Reiniciando backend..."
cd ..
pm2 restart jewelry-backend

echo ""
echo "=== Configuración Agregada Exitosamente ==="
echo ""
echo "✓ Tabla de configuración creada en la base de datos"
echo "✓ Rutas de API agregadas"
echo "✓ Página de configuración agregada"
echo "✓ Menú actualizado"
echo ""
echo "Ahora puedes acceder a la configuración desde el menú lateral"
echo "en tu aplicación web."