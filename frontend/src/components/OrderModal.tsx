import { useState, useEffect, FormEvent } from 'react';
import { X, Plus, Trash2 } from 'lucide-react';
import api from '../services/api';
import { Product, Customer, Order } from '../types';
import SearchableSelect from './SearchableSelect';
import './Modal.css';
import './OrderModal.css';

interface OrderModalProps {
  order?: Order;
  onClose: () => void;
}

interface OrderItem {
  product_id: number;
  product?: Product;
  quantity: number;
  unit_price: number;
  total: number;
}

const OrderModal = ({ order, onClose }: OrderModalProps) => {
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
    
    if (order) {
      // Cargar datos del pedido existente
      setSelectedCustomer(order.customer_id);
      setCustomerName(order.customer_name);
      setPaymentMethod(order.payment_method);
      setIsAnonymous(!order.customer_id);
      
      // Cargar items del pedido
      if (order.items) {
        setOrderItems(order.items.map(item => ({
          product_id: item.product_id,
          product: products.find(p => p.id === item.product_id),
          quantity: item.quantity,
          unit_price: item.unit_price,
          total: item.total
        })));
      }
    }
  }, [order]);

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

  const handleProductChange = (index: number, productId: number | null) => {
    if (!productId) return;
    
    const product = products.find(p => p.id === productId);
    if (!product) return;

    const newItems = [...orderItems];
    newItems[index] = {
      ...newItems[index],
      product_id: productId,
      product: product,
      unit_price: parseFloat(String(product.price)),
      total: parseFloat(String(product.price)) * newItems[index].quantity
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

      if (order) {
        await api.put(`/orders/${order.id}`, orderData);
      } else {
        await api.post('/orders', orderData);
      }
      
      onClose();
    } catch (err: any) {
      setError(err.response?.data?.error || 'Error al guardar el pedido');
    } finally {
      setLoading(false);
    }
  };

  // Preparar opciones para los selects
  const customerOptions = customers.map(customer => ({
    id: customer.id,
    label: customer.name,
    subLabel: customer.dni || customer.phone || 'Sin datos'
  }));

  const productOptions = products.map(product => ({
    id: product.id,
    label: product.name,
    subLabel: `S/ ${parseFloat(String(product.price)).toFixed(2)} - Stock: ${product.stock}`
  }));

  return (
    <div className="modal-overlay">
      <div className="modal order-modal">
        <div className="modal-header">
          <h2>{order ? 'Editar Pedido' : 'Nuevo Pedido'}</h2>
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
                <SearchableSelect
                  label="Seleccionar Cliente"
                  options={customerOptions}
                  value={selectedCustomer}
                  onChange={(value) => {
                    setSelectedCustomer(value);
                    const customer = customers.find(c => c.id === value);
                    setCustomerName(customer?.name || '');
                  }}
                  placeholder="Buscar cliente por nombre o DNI..."
                  required={!isAnonymous}
                />
              </div>
            )}
          </div>

          <div className="form-section">
            <h3>Productos</h3>
            <div className="order-items">
              {orderItems.map((item, index) => (
                <div key={index} className="order-item-row">
                  <div className="product-select-wrapper">
                    <SearchableSelect
                      options={productOptions.filter(p => {
                        const product = products.find(prod => prod.id === p.id);
                        return product && product.stock > 0;
                      })}
                      value={item.product_id || null}
                      onChange={(value) => handleProductChange(index, value)}
                      placeholder="Buscar producto..."
                    />
                  </div>
                  
                  <input
                    type="number"
                    value={item.quantity}
                    onChange={(e) => handleQuantityChange(index, parseInt(e.target.value))}
                    min="1"
                    className="quantity-input"
                    required
                  />
                  
                  <span className="item-total">S/ {parseFloat(String(item.total)).toFixed(2)}</span>
                  
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
              <strong>Total:</strong> S/ {parseFloat(String(calculateTotal())).toFixed(2)}
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
              {loading ? 'Guardando...' : order ? 'Actualizar Pedido' : 'Crear Pedido'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default OrderModal;