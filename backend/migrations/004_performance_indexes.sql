-- Índices para mejorar el rendimiento de consultas frecuentes

-- Índices para la tabla orders
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_orders_order_id ON orders(order_id);

-- Índices para la tabla order_items
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- Índices para la tabla products
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_stock ON products(stock);

-- Índices para la tabla customers
CREATE INDEX idx_customers_dni ON customers(dni);
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_name ON customers(name);

-- Índice compuesto para búsquedas de pedidos por estado y fecha
CREATE INDEX idx_orders_status_date ON orders(status, created_at DESC);

-- Índice para búsquedas de productos por categoría y stock
CREATE INDEX idx_products_category_stock ON products(category_id, stock);