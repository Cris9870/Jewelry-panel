import { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Upload, Search } from 'lucide-react';
import api from '../services/api';
import { Product, Category } from '../types';
import ProductModal from '../components/ProductModal';
import BulkUploadModal from '../components/BulkUploadModal';
import './Products.css';

const Products = () => {
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isBulkModalOpen, setIsBulkModalOpen] = useState(false);

  useEffect(() => {
    fetchProducts();
    fetchCategories();
  }, []);

  const fetchProducts = async () => {
    try {
      const response = await api.get('/products');
      setProducts(response.data);
    } catch (error) {
      console.error('Error fetching products:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchCategories = async () => {
    try {
      const response = await api.get('/products/categories/all');
      setCategories(response.data);
    } catch (error) {
      console.error('Error fetching categories:', error);
    }
  };

  const handleDelete = async (id: number) => {
    if (!window.confirm('¿Está seguro de eliminar este producto?')) return;

    try {
      await api.delete(`/products/${id}`);
      fetchProducts();
    } catch (error) {
      console.error('Error deleting product:', error);
    }
  };

  const handleEdit = (product: Product) => {
    setSelectedProduct(product);
    setIsModalOpen(true);
  };

  const handleModalClose = () => {
    setSelectedProduct(null);
    setIsModalOpen(false);
    fetchProducts();
  };

  const filteredProducts = products.filter(product =>
    product.name.toLowerCase().includes(search.toLowerCase()) ||
    product.sku.toLowerCase().includes(search.toLowerCase())
  );

  if (loading) {
    return <div className="loading">Cargando...</div>;
  }

  return (
    <div className="products">
      <div className="page-header">
        <h1 className="page-title">Productos</h1>
        <div className="header-actions">
          <button className="btn btn-secondary" onClick={() => setIsBulkModalOpen(true)}>
            <Upload size={20} />
            Carga Masiva
          </button>
          <button className="btn btn-primary" onClick={() => setIsModalOpen(true)}>
            <Plus size={20} />
            Nuevo Producto
          </button>
        </div>
      </div>

      <div className="products-filters">
        <div className="search-box">
          <Search size={20} />
          <input
            type="text"
            placeholder="Buscar productos..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>

      <div className="products-table-container">
        <table className="products-table">
          <thead>
            <tr>
              <th>SKU</th>
              <th>Nombre</th>
              <th>Categoría</th>
              <th>Precio</th>
              <th>Stock</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {filteredProducts.map((product) => (
              <tr key={product.id}>
                <td>{product.sku}</td>
                <td>
                  <div className="product-name">
                    {product.image_url && (
                      <img src={`http://localhost:5000${product.image_url}`} alt={product.name} />
                    )}
                    <span>{product.name}</span>
                  </div>
                </td>
                <td>{product.category_name || '-'}</td>
                <td>S/ {product.price.toFixed(2)}</td>
                <td>
                  <span className={`stock ${product.stock === 0 ? 'out-of-stock' : ''}`}>
                    {product.stock}
                  </span>
                </td>
                <td>
                  <div className="table-actions">
                    <button className="btn-icon" onClick={() => handleEdit(product)}>
                      <Edit size={18} />
                    </button>
                    <button className="btn-icon btn-danger" onClick={() => handleDelete(product.id)}>
                      <Trash2 size={18} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {isModalOpen && (
        <ProductModal
          product={selectedProduct}
          categories={categories}
          onClose={handleModalClose}
        />
      )}

      {isBulkModalOpen && (
        <BulkUploadModal
          onClose={() => {
            setIsBulkModalOpen(false);
            fetchProducts();
          }}
        />
      )}
    </div>
  );
};

export default Products;