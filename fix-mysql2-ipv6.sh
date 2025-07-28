#!/bin/bash

echo "=== Corrigiendo MySQL2 IPv6 Issue ==="
echo ""

cd /opt/jewelry-panel/backend

# 1. Hacer backup del server.js
cp server.js server.js.backup

# 2. Modificar server.js para forzar IPv4
echo "1. Modificando server.js para forzar IPv4..."
cat > server.js << 'EOF'
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const authRoutes = require('./routes/auth');
const productRoutes = require('./routes/products');
const customerRoutes = require('./routes/customers');
const orderRoutes = require('./routes/orders');
const dashboardRoutes = require('./routes/dashboard');
const { errorHandler } = require('./middleware/errorHandler');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static('uploads'));

// Forzar IPv4 en la conexión MySQL
const pool = mysql.createPool({
  host: '127.0.0.1', // Hardcoded IPv4
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  // Forzar familia IPv4
  socketPath: undefined,
  flags: undefined
});

// Verificar conexión al inicio
pool.getConnection()
  .then(connection => {
    console.log('✓ Conexión a MySQL establecida');
    connection.release();
  })
  .catch(err => {
    console.error('✗ Error conectando a MySQL:', err.message);
  });

global.db = pool;

app.use('/api/auth', authRoutes);
app.use('/api/products', productRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/dashboard', dashboardRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
EOF

# 3. Reiniciar PM2
echo ""
echo "2. Reiniciando servidor..."
pm2 delete all
pm2 start server.js --name jewelry-backend

# 4. Esperar
sleep 3

# 5. Verificar logs
echo ""
echo "3. Verificando logs..."
pm2 logs jewelry-backend --lines 20 --nostream

# 6. Probar conexión
echo ""
echo "4. Probando login..."
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

echo ""
echo ""
echo "=== Proceso Completado ==="