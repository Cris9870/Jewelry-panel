import { useState, useEffect } from 'react';
import { Plus, Eye, FileText, Filter, X } from 'lucide-react';
import api from '../services/api';
import { Order } from '../types';
import OrderModal from '../components/OrderModal';
import { format } from 'date-fns';
import './Orders.css';

const Orders = () => {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);

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

  const handleStatusChange = async (orderId: number, newStatus: string) => {
    try {
      await api.put(`/orders/${orderId}/status`, { status: newStatus });
      fetchOrders();
    } catch (error) {
      console.error('Error updating order status:', error);
    }
  };

  const handleViewOrder = (order: Order) => {
    setSelectedOrder(order);
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
        <button className="btn btn-primary" onClick={() => setIsModalOpen(true)}>
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
                <td>S/ {order.total.toFixed(2)}</td>
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
                    <button className="btn-icon" onClick={() => handleViewOrder(order)}>
                      <Eye size={18} />
                    </button>
                    <button className="btn-icon" onClick={() => handleDownloadPDF(order.id)}>
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
          onClose={() => {
            setIsModalOpen(false);
            fetchOrders();
          }}
        />
      )}

      {selectedOrder && (
        <div className="modal-overlay" onClick={() => setSelectedOrder(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Detalles del Pedido</h2>
              <button className="modal-close" onClick={() => setSelectedOrder(null)}>
                <X size={24} />
              </button>
            </div>
            <div className="order-details">
              <p><strong>N° Pedido:</strong> {selectedOrder.order_id}</p>
              <p><strong>Cliente:</strong> {selectedOrder.customer_name}</p>
              <p><strong>Total:</strong> S/ {selectedOrder.total.toFixed(2)}</p>
              <p><strong>Estado:</strong> {selectedOrder.status}</p>
              <p><strong>Método de Pago:</strong> {selectedOrder.payment_method}</p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Orders;