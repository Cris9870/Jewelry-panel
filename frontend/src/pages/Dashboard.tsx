import { useEffect, useState } from 'react';
import { DollarSign, ShoppingBag, CheckCircle, Clock, XCircle, TrendingUp } from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import api from '../services/api';
import { DashboardStats } from '../types';
import './Dashboard.css';

const Dashboard = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboardStats();
  }, []);

  const fetchDashboardStats = async () => {
    try {
      const response = await api.get('/dashboard/stats');
      setStats(response.data);
    } catch (error) {
      console.error('Error fetching dashboard stats:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="loading">Cargando...</div>;
  }

  if (!stats) {
    return <div className="error">Error al cargar los datos</div>;
  }

  const statsCards = [
    {
      title: 'Total Sales',
      value: `S/ ${stats.totalSales.toFixed(2)}`,
      percentage: '75.55%',
      icon: DollarSign,
      color: 'warning',
      trend: 'up'
    },
    {
      title: 'Total Orders',
      value: stats.totalOrders.toString(),
      percentage: '3%',
      icon: ShoppingBag,
      color: 'danger',
      trend: 'down'
    },
    {
      title: 'Order Complete',
      value: stats.completedOrders.toString(),
      percentage: '98%',
      icon: CheckCircle,
      color: 'info',
      trend: 'up'
    },
    {
      title: 'Cancel Order',
      value: stats.canceledOrders.toString(),
      percentage: '2%',
      icon: XCircle,
      color: 'danger',
      trend: 'down'
    }
  ];

  const chartData = stats.monthlySales.map(item => ({
    month: item.month,
    sales: item.total
  }));

  return (
    <div className="dashboard">
      <h1 className="page-title">Dashboard</h1>

      <div className="stats-grid">
        {statsCards.map((card, index) => (
          <div key={index} className="stat-card">
            <div className="stat-icon" data-color={card.color}>
              <card.icon size={24} />
            </div>
            <div className="stat-content">
              <p className="stat-title">{card.title}</p>
              <h3 className="stat-value">{card.value}</h3>
              <div className="stat-footer">
                <span className={`stat-percentage ${card.trend}`}>
                  {card.trend === 'up' ? '↑' : '↓'} {card.percentage}
                </span>
                <span className="stat-period">vs last month</span>
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="dashboard-row">
        <div className="chart-container">
          <div className="section-header">
            <h2>Revenue and Sales</h2>
            <div className="legend">
              <span className="legend-item" data-color="blue">Revenue</span>
              <span className="legend-item" data-color="red">Sales</span>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="month" />
              <YAxis />
              <Tooltip />
              <Line type="monotone" dataKey="sales" stroke="#87ceeb" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="latest-orders">
          <div className="section-header">
            <h2>Latest Order</h2>
            <a href="/orders" className="view-all">See All</a>
          </div>
          <div className="orders-list">
            {stats.recentOrders.map((order) => (
              <div key={order.id} className="order-item">
                <div className="order-info">
                  <p className="order-customer">{order.customer_name}</p>
                  <p className="order-id">{order.order_id}</p>
                </div>
                <div className="order-details">
                  <p className="order-total">S/ {order.total.toFixed(2)}</p>
                  <span className={`order-status status-${order.status.toLowerCase().replace(' ', '-')}`}>
                    {order.status}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;