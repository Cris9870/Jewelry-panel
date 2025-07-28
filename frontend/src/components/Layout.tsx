import { Outlet, Link, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { LayoutDashboard, Package, Users, ShoppingBag, Settings, LogOut, Gem } from 'lucide-react';
import './Layout.css';

const Layout = () => {
  const { user, logout } = useAuth();
  const location = useLocation();

  const menuItems = [
    { path: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
    { path: '/orders', icon: ShoppingBag, label: 'Pedidos' },
    { path: '/products', icon: Package, label: 'Productos' },
    { path: '/customers', icon: Users, label: 'Clientes' },
    { path: '/settings', icon: Settings, label: 'Configuración' },
  ];

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="sidebar-header">
          <Gem className="logo-icon" />
          <h2>Q'BellaJoyeria</h2>
        </div>
        
        <nav className="sidebar-nav">
          {menuItems.map((item) => (
            <Link
              key={item.path}
              to={item.path}
              className={`nav-item ${location.pathname === item.path ? 'active' : ''}`}
            >
              <item.icon size={20} />
              <span>{item.label}</span>
            </Link>
          ))}
        </nav>

        <div className="sidebar-footer">
          <button className="logout-btn" onClick={logout}>
            <LogOut size={20} />
            <span>Cerrar sesión</span>
          </button>
        </div>
      </aside>

      <div className="main-content">
        <header className="main-header">
          <div className="header-right">
            <span className="user-name">{user?.username}</span>
          </div>
        </header>
        
        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
};

export default Layout;