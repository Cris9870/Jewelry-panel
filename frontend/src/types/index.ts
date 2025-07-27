export interface User {
  id: number;
  username: string;
}

export interface Product {
  id: number;
  sku: string;
  name: string;
  price: number;
  category_id: number | null;
  category_name?: string;
  attributes?: any;
  stock: number;
  image_url?: string;
  created_at: string;
  updated_at: string;
}

export interface Customer {
  id: number;
  name: string;
  email?: string;
  phone?: string;
  address?: string;
  dni?: string;
  created_at: string;
  updated_at: string;
}

export interface OrderItem {
  id: number;
  product_id: number;
  quantity: number;
  unit_price: number;
  total: number;
  name?: string;
  sku?: string;
}

export interface Order {
  id: number;
  order_id: string;
  customer_id: number | null;
  customer_name: string;
  total: number;
  status: 'Pendiente de Pago' | 'Pagado' | 'Cancelado';
  payment_method: 'Yape/Plin' | 'Efectivo' | 'Transf. bancaria' | 'Tarjeta';
  created_at: string;
  updated_at: string;
  items?: OrderItem[];
}

export interface Category {
  id: number;
  name: string;
}

export interface DashboardStats {
  totalSales: number;
  totalOrders: number;
  completedOrders: number;
  pendingOrders: number;
  canceledOrders: number;
  recentOrders: Order[];
  monthlySales: {
    month: string;
    total: number;
    count: number;
  }[];
}