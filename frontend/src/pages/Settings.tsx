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