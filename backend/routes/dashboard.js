const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');

router.get('/stats', authMiddleware, async (req, res, next) => {
  try {
    const [totalSales] = await global.db.query(
      "SELECT SUM(total) as total FROM orders WHERE status = 'Pagado'"
    );
    
    const [totalOrders] = await global.db.query(
      'SELECT COUNT(*) as count FROM orders'
    );
    
    const [completedOrders] = await global.db.query(
      "SELECT COUNT(*) as count FROM orders WHERE status = 'Pagado'"
    );
    
    const [pendingOrders] = await global.db.query(
      "SELECT COUNT(*) as count FROM orders WHERE status = 'Pendiente de Pago'"
    );
    
    const [canceledOrders] = await global.db.query(
      "SELECT COUNT(*) as count FROM orders WHERE status = 'Cancelado'"
    );
    
    const [recentOrders] = await global.db.query(`
      SELECT o.*, c.name as customer_name 
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
      ORDER BY o.created_at DESC
      LIMIT 10
    `);
    
    const [monthlySales] = await global.db.query(`
      SELECT 
        DATE_FORMAT(created_at, '%Y-%m') as month,
        SUM(total) as total,
        COUNT(*) as count
      FROM orders
      WHERE status = 'Pagado'
      AND created_at >= DATE_SUB(NOW(), INTERVAL 12 MONTH)
      GROUP BY DATE_FORMAT(created_at, '%Y-%m')
      ORDER BY month
    `);
    
    res.json({
      totalSales: totalSales[0].total || 0,
      totalOrders: totalOrders[0].count,
      completedOrders: completedOrders[0].count,
      pendingOrders: pendingOrders[0].count,
      canceledOrders: canceledOrders[0].count,
      recentOrders,
      monthlySales
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;