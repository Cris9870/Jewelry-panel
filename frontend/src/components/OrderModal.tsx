import { useState, useEffect, FormEvent } from 'react';
import { X, Plus, Trash2 } from 'lucide-react';
import api from '../services/api';
import { Product, Customer } from '../types';
import './Modal.css';
import './OrderModal.css';

interface OrderModalProps {
  onClose: () => void;
}

interface OrderItem {
  product_id: number;
  product?: Product;
  quantity: number;
  unit_price: number;
  total: number;
}

const OrderModal = ({ onClose }: OrderModalProps) => {
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [selectedCustomer, setSelectedCustomer] = useState<number | null>(null);
  const [isAnonymous, setIsAnonymous] = useState(false);
  const [customerName, setCustomerName] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('Yape/Plin');
  const [orderItems, setOrderItems] = useState<OrderItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchCustomers();
    fetchProducts();
  }, []);

  const fetchCustomers = async () => {
    try {
      const response = await api.get('/customers');
      setCustomers(response.data);
    } catch (error) {
      console.error('Error fetching customers:', error);
    }
  };

  const fetchProducts = async () => {
    try {
      const response = await api.get('/products');
      setProducts(response.data);
    } catch (error) {
      console.error('Error fetching products:', error);
    }
  };

  const handleAddItem = () => {
    setOrderItems([...orderItems, {
      product_id: 0,
      quantity: 1,
      unit_price: 0,
      total: 0
    }]);
  };

  const handleRemoveItem = (index: number) => {
    setOrderItems(orderItems.filter((_, i) => i !== index));
  };

  const handleProductChange = (index: number, productId: number) => {
    const product = products.find(p => p.id === productId);
    if (!product) return;

    const newItems = [...orderItems];
    newItems[index] = {
      ...newItems[index],
      product_id: productId,
      product: product,
      unit_price: product.price,
      total: product.price * newItems[index].quantity
    };
    setOrderItems(newItems);
  };

  const handleQuantityChange = (index: number, quantity: number) => {
    if (quantity < 1) return;

    const product = orderItems[index].product;
    if (product && quantity > product.stock) {
      setError(`Stock insuficiente. Stock disponible: ${product.stock}`);
      return;
    }

    const newItems = [...orderItems];
    newItems[index] = {
      ...newItems[index],
      quantity: quantity,
      total: newItems[index].unit_price * quantity
    };
    setOrderItems(newItems);
    setError('');
  };

  const calculateTotal = () => {
    return orderItems.reduce((sum, item) => sum + item.total, 0);
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    if (orderItems.length === 0) {
      setError('Debe agregar al menos un producto');
      setLoading(false);
      return;
    }

    const validItems = orderItems.filter(item => item.product_id > 0);
    if (validItems.length === 0) {
      setError('Debe seleccionar productos válidos');
      setLoading(false);
      return;
    }

    try {
      const orderData = {
        customer_id: isAnonymous ? null : selectedCustomer,
        customer_name: isAnonymous ? 'Anónimo' : customerName,
        payment_method: paymentMethod,
        items: validItems.map(item => ({
          product_id: item.product_id,
          quantity: item.quantity
        }))
      };

      await api.post('/orders', orderData);
      onClose();
    } catch (err: any) {
      setError(err.response?.data?.error || 'Error al crear el pedido');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal order-modal">
        <div className="modal-header">
          <h2>Nuevo Pedido</h2>
          <button className="modal-close" onClick={onClose}>
            <X size={24} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="modal-form">
          {error && <div className="error-message">{error}</div>}

          <div className="form-section">
            <h3>Cliente</h3>
            <div className="form-group">
              <label>
                <input
                  type="checkbox"
                  checked={isAnonymous}
                  onChange={(e) => setIsAnonymous(e.target.checked)}
                />
                Cliente Anónimo
              </label>
            </div>

            {!isAnonymous && (
              <div className="form-group">
                <label>Seleccionar Cliente</label>
                <select
                  value={selectedCustomer || ''}
                  onChange={(e) => {
                    const customerId = parseInt(e.target.value);
                    setSelectedCustomer(customerId);
                    const customer = customers.find(c => c.id === customerId);
                    setCustomerName(customer?.name || '');
                  }}
                  required={!isAnonymous}
                >
                  <option value="">Seleccione un cliente</option>
                  {customers.map((customer) => (
                    <option key={customer.id} value={customer.id}>
                      {customer.name} - {customer.dni || 'Sin DNI'}
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>

          <div className="form-section">
            <h3>Productos</h3>
            <div className="order-items">
              {orderItems.map((item, index) => (
                <div key={index} className="order-item-row">
                  <select
                    value={item.product_id}
                    onChange={(e) => handleProductChange(index, parseInt(e.target.value))}
                    className="product-select"
                    required
                  >
                    <option value={0}>Seleccione un producto</option>
                    {products.map((product) => (
                      <option key={product.id} value={product.id} disabled={product.stock === 0}>
                        {product.name} - S/ {product.price} (Stock: {product.stock})
                      </option>
                    ))}
                  </select>
                  
                  <input
                    type="number"
                    value={item.quantity}
                    onChange={(e) => handleQuantityChange(index, parseInt(e.target.value))}
                    min="1"
                    className="quantity-input"
                    required
                  />
                  
                  <span className="item-total">S/ {item.total.toFixed(2)}</span>
                  
                  <button
                    type="button"
                    className="btn-icon btn-danger"
                    onClick={() => handleRemoveItem(index)}
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
              ))}
              
              <button type="button" className="btn btn-secondary" onClick={handleAddItem}>
                <Plus size={20} />
                Agregar Producto
              </button>
            </div>
            
            <div className="order-total">
              <strong>Total:</strong> S/ {calculateTotal().toFixed(2)}
            </div>
          </div>

          <div className="form-section">
            <h3>Método de Pago</h3>
            <div className="form-group">
              <select
                value={paymentMethod}
                onChange={(e) => setPaymentMethod(e.target.value)}
                required
              >
                <option value="Yape/Plin">Yape/Plin</option>
                <option value="Efectivo">Efectivo</option>
                <option value="Transf. bancaria">Transf. bancaria</option>
                <option value="Tarjeta">Tarjeta</option>
              </select>
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" className="btn btn-cancel" onClick={onClose}>
              Cancelar
            </button>
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? 'Creando...' : 'Crear Pedido'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default OrderModal;