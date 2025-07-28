import { useState, useEffect } from 'react';
import { Plus, Eye, FileText, Filter, X, Edit } from 'lucide-react';
import api from '../services/api';
import { Order } from '../types';
import OrderModal from '../components/OrderModal';
import { format } from 'date-fns';
// Importar CSS de Orders y del Modal para asegurar que se carguen
import './Orders.css';
import '../components/Modal.css';

const Orders = () => {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingOrder, setEditingOrder] = useState<Order | null>(null);
  const [viewingOrder, setViewingOrder] = useState<Order | null>(null);

  useEffect(() => {
    fetchOrders();
  }, [statusFilter]);

  const fetchOrders = async () => {
    try {
      const response = await api.get('/orders', {
        params: statusFilter ? { status: statusFilter } : {}
      });
      setOrders(response.data);
    } catch (error) {
      console.error('Error fetching orders:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchOrderDetails = async (orderId: number) => {
    try {
      const response = await api.get(`/orders/${orderId}`);
      return response.data;
    } catch (error) {
      console.error('Error fetching order details:', error);
      return null;
    }
  };

  const handleStatusChange = async (orderId: number, newStatus: string) => {
    try {
      await api.put(`/orders/${orderId}/status`, { status: newStatus });
      fetchOrders();
    } catch (error) {
      console.error('Error updating order status:', error);
    }
  };

  const handleViewOrder = async (order: Order) => {
    const orderWithDetails = await fetchOrderDetails(order.id);
    if (orderWithDetails) {
      setViewingOrder(orderWithDetails);
    }
  };

  const handleEditOrder = async (order: Order) => {
    const orderWithDetails = await fetchOrderDetails(order.id);
    if (orderWithDetails) {
      setEditingOrder(orderWithDetails);
      setIsModalOpen(true);
    }
  };

  const handleDownloadPDF = async (orderId: number) => {
    try {
      const response = await api.get(`/orders/${orderId}/pdf`, {
        responseType: 'blob'
      });
      
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `pedido-${orderId}.pdf`);
      document.body.appendChild(link);
      link.click();
      link.remove();
    } catch (error) {
      console.error('Error downloading PDF:', error);
    }
  };

  if (loading) {
    return <div className="loading">Cargando...</div>;
  }

  return (
    <div className="orders">
      <div className="page-header">
        <h1 className="page-title">Pedidos</h1>
        <button className="btn btn-primary" onClick={() => {
          setEditingOrder(null);
          setIsModalOpen(true);
        }}>
          <Plus size={20} />
          Nuevo Pedido
        </button>
      </div>

      <div className="orders-filters">
        <div className="filter-group">
          <Filter size={20} />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="status-filter"
          >
            <option value="">Todos los estados</option>
            <option value="Pendiente de Pago">Pendiente de Pago</option>
            <option value="Pagado">Pagado</option>
            <option value="Cancelado">Cancelado</option>
          </select>
        </div>
      </div>

      <div className="orders-table-container">
        <table className="orders-table">
          <thead>
            <tr>
              <th>N° Pedido</th>
              <th>Cliente</th>
              <th>Total</th>
              <th>Método de Pago</th>
              <th>Estado</th>
              <th>Fecha</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {orders.map((order) => (
              <tr key={order.id}>
                <td>{order.order_id}</td>
                <td>{order.customer_name}</td>
                <td>S/ {parseFloat(String(order.total)).toFixed(2)}</td>
                <td>{order.payment_method}</td>
                <td>
                  <select
                    className={`status-select status-${order.status.toLowerCase().replace(' ', '-')}`}
                    value={order.status}
                    onChange={(e) => handleStatusChange(order.id, e.target.value)}
                  >
                    <option value="Pendiente de Pago">Pendiente de Pago</option>
                    <option value="Pagado">Pagado</option>
                    <option value="Cancelado">Cancelado</option>
                  </select>
                </td>
                <td>{format(new Date(order.created_at), 'dd/MM/yyyy HH:mm')}</td>
                <td>
                  <div className="table-actions">
                    <button 
                      className="btn-icon" 
                      onClick={() => handleViewOrder(order)}
                      title="Ver detalles"
                    >
                      <Eye size={18} />
                    </button>
                    <button 
                      className="btn-icon" 
                      onClick={() => handleEditOrder(order)}
                      title="Editar pedido"
                    >
                      <Edit size={18} />
                    </button>
                    <button 
                      className="btn-icon" 
                      onClick={() => handleDownloadPDF(order.id)}
                      title="Descargar PDF"
                    >
                      <FileText size={18} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {isModalOpen && (
        <OrderModal
          order={editingOrder || undefined}
          onClose={() => {
            setIsModalOpen(false);
            setEditingOrder(null);
            fetchOrders();
          }}
        />
      )}

      {viewingOrder && (
        <div className="modal-overlay" onClick={() => setViewingOrder(null)}>
          <div className="modal order-details-modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Detalles del Pedido</h2>
              <button className="modal-close" onClick={() => setViewingOrder(null)}>
                <X size={24} />
              </button>
            </div>
            <div className="order-details">
              <div className="detail-section">
                <h3>Información General</h3>
                <p><strong>N° Pedido:</strong> {viewingOrder.order_id}</p>
                <p><strong>Cliente:</strong> {viewingOrder.customer_name}</p>
                <p><strong>Estado:</strong> <span className={`status status-${viewingOrder.status.toLowerCase().replace(' ', '-')}`}>{viewingOrder.status}</span></p>
                <p><strong>Método de Pago:</strong> {viewingOrder.payment_method}</p>
                <p><strong>Fecha:</strong> {format(new Date(viewingOrder.created_at), 'dd/MM/yyyy HH:mm')}</p>
              </div>

              {viewingOrder.items && viewingOrder.items.length > 0 && (
                <div className="detail-section">
                  <h3>Productos</h3>
                  <table className="items-table">
                    <thead>
                      <tr>
                        <th>Producto</th>
                        <th>SKU</th>
                        <th>Precio Unit.</th>
                        <th>Cantidad</th>
                        <th>Total</th>
                      </tr>
                    </thead>
                    <tbody>
                      {viewingOrder.items.map((item, index) => (
                        <tr key={index}>
                          <td>{item.name || `Producto ${item.product_id}`}</td>
                          <td>{item.sku || '-'}</td>
                          <td>S/ {parseFloat(String(item.unit_price)).toFixed(2)}</td>
                          <td>{item.quantity}</td>
                          <td>S/ {parseFloat(String(item.total)).toFixed(2)}</td>
                        </tr>
                      ))}
                    </tbody>
                    <tfoot>
                      <tr>
                        <td colSpan={4} style={{ textAlign: 'right' }}><strong>Total:</strong></td>
                        <td><strong>S/ {parseFloat(String(viewingOrder.total)).toFixed(2)}</strong></td>
                      </tr>
                    </tfoot>
                  </table>
                </div>
              )}

              <div className="modal-footer">
                <button 
                  className="btn btn-secondary" 
                  onClick={() => {
                    setViewingOrder(null);
                    handleEditOrder(viewingOrder);
                  }}
                >
                  <Edit size={20} />
                  Editar Pedido
                </button>
                <button 
                  className="btn btn-primary" 
                  onClick={() => handleDownloadPDF(viewingOrder.id)}
                >
                  <FileText size={20} />
                  Descargar PDF
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Orders;