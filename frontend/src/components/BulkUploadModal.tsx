import { useState, FormEvent } from 'react';
import { X, Download } from 'lucide-react';
import api from '../services/api';
import './Modal.css';

interface BulkUploadModalProps {
  onClose: () => void;
}

const BulkUploadModal = ({ onClose }: BulkUploadModalProps) => {
  const [file, setFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!file) return;

    setLoading(true);
    const formData = new FormData();
    formData.append('file', file);

    try {
      const response = await api.post('/products/bulk-upload', formData);
      setResult(response.data);
    } catch (error) {
      console.error('Error uploading file:', error);
    } finally {
      setLoading(false);
    }
  };

  const downloadTemplate = () => {
    const template = 'SKU,Nombre,Precio,Stock,Categoría\n' +
      'JOY001,Anillo de Oro,1500.00,10,1\n' +
      'JOY002,Collar de Plata,800.00,5,2';
    
    const blob = new Blob([template], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'plantilla_productos.csv';
    a.click();
  };

  return (
    <div className="modal-overlay">
      <div className="modal">
        <div className="modal-header">
          <h2>Carga Masiva de Productos</h2>
          <button className="modal-close" onClick={onClose}>
            <X size={24} />
          </button>
        </div>

        <div className="modal-form">
          {!result ? (
            <>
              <div className="upload-info">
                <p>Suba un archivo Excel o CSV con los productos a importar.</p>
                <button type="button" className="btn btn-secondary" onClick={downloadTemplate}>
                  <Download size={20} />
                  Descargar Plantilla
                </button>
              </div>

              <form onSubmit={handleSubmit}>
                <div className="form-group">
                  <label>Archivo</label>
                  <input
                    type="file"
                    accept=".xlsx,.xls,.csv"
                    onChange={(e) => setFile(e.target.files?.[0] || null)}
                    required
                  />
                </div>

                <div className="modal-footer">
                  <button type="button" className="btn btn-cancel" onClick={onClose}>
                    Cancelar
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={loading || !file}>
                    {loading ? 'Procesando...' : 'Subir Archivo'}
                  </button>
                </div>
              </form>
            </>
          ) : (
            <div className="upload-result">
              <h3>Resultado de la Importación</h3>
              <div className="result-stats">
                <p className="success">✓ Productos importados: {result.success}</p>
                <p className="error">✗ Productos con error: {result.failed}</p>
              </div>
              
              {result.errors.length > 0 && (
                <div className="error-details">
                  <h4>Errores encontrados:</h4>
                  {result.errors.slice(0, 5).map((error: any, index: number) => (
                    <p key={index}>{error.error}</p>
                  ))}
                  {result.errors.length > 5 && (
                    <p>... y {result.errors.length - 5} errores más</p>
                  )}
                </div>
              )}

              <div className="modal-footer">
                <button className="btn btn-primary" onClick={onClose}>
                  Cerrar
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default BulkUploadModal;