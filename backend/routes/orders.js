const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { generateOrderId, generateOrderPDF } = require('../utils/orderUtils');
const { body, validationResult } = require('express-validator');

router.get('/', authMiddleware, async (req, res, next) => {
  try {
    const { status } = req.query;
    let query = `
      SELECT o.*, c.name as customer_name 
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
    `;
    let params = [];
    
    if (status) {
      query += ' WHERE o.status = ?';
      params.push(status);
    }
    
    query += ' ORDER BY o.created_at DESC';
    
    const [orders] = await global.db.query(query, params);
    res.json(orders);
  } catch (error) {
    next(error);
  }
});

router.get('/:id', authMiddleware, async (req, res, next) => {
  try {
    const [orders] = await global.db.query(`
      SELECT o.*, c.* 
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
      WHERE o.id = ?
    `, [req.params.id]);
    
    if (orders.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }
    
    const [items] = await global.db.query(`
      SELECT oi.*, p.name, p.sku 
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    `, [req.params.id]);
    
    orders[0].items = items;
    
    res.json(orders[0]);
  } catch (error) {
    next(error);
  }
});

router.post('/', authMiddleware, [
  body('items').isArray().withMessage('Items must be an array'),
  body('items.*.product_id').isInt().withMessage('Product ID must be an integer'),
  body('items.*.quantity').isInt({ min: 1 }).withMessage('Quantity must be at least 1')
], async (req, res, next) => {
  const connection = await global.db.getConnection();
  
  try {
    await connection.beginTransaction();
    
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { customer_id, customer_name, items, payment_method } = req.body;
    const order_id = generateOrderId();
    
    for (const item of items) {
      const [products] = await connection.query(
        'SELECT stock FROM products WHERE id = ? FOR UPDATE',
        [item.product_id]
      );
      
      if (products.length === 0) {
        throw new Error(`Product with ID ${item.product_id} not found`);
      }
      
      if (products[0].stock < item.quantity) {
        throw new Error(`Insufficient stock for product ID ${item.product_id}`);
      }
    }
    
    let total = 0;
    for (const item of items) {
      const [products] = await connection.query(
        'SELECT price FROM products WHERE id = ?',
        [item.product_id]
      );
      total += products[0].price * item.quantity;
    }
    
    const [orderResult] = await connection.query(
      'INSERT INTO orders (order_id, customer_id, customer_name, total, payment_method) VALUES (?, ?, ?, ?, ?)',
      [order_id, customer_id || null, customer_name || 'Anónimo', total, payment_method || 'Yape/Plin']
    );
    
    // Obtener todos los productos en una sola consulta
    const productIds = items.map(item => item.product_id);
    const [products] = await connection.query(
      'SELECT id, price FROM products WHERE id IN (?)',
      [productIds]
    );
    
    // Crear un mapa de productos para acceso rápido
    const productMap = {};
    products.forEach(p => productMap[p.id] = p);
    
    // Preparar datos para inserción batch
    const orderItemsData = items.map(item => {
      const product = productMap[item.product_id];
      const itemTotal = product.price * item.quantity;
      return [orderResult.insertId, item.product_id, item.quantity, product.price, itemTotal];
    });
    
    // Insertar todos los items de una vez
    await connection.query(
      'INSERT INTO order_items (order_id, product_id, quantity, unit_price, total) VALUES ?',
      [orderItemsData]
    );
    
    // Actualizar stock de todos los productos en una consulta
    const stockUpdates = items.map(item => 
      `WHEN ${item.product_id} THEN stock - ${item.quantity}`
    ).join(' ');
    
    await connection.query(
      `UPDATE products 
       SET stock = CASE id ${stockUpdates} ELSE stock END 
       WHERE id IN (?)`,
      [productIds]
    );
    
    await connection.commit();
    
    res.status(201).json({
      id: orderResult.insertId,
      order_id: order_id,
      message: 'Order created successfully'
    });
  } catch (error) {
    await connection.rollback();
    next(error);
  } finally {
    connection.release();
  }
});

// Actualizar pedido completo
router.put('/:id', authMiddleware, async (req, res, next) => {
  const connection = await global.db.getConnection();
  
  try {
    await connection.beginTransaction();
    
    const { items, payment_method, status } = req.body;
    const orderId = req.params.id;
    
    // Obtener el pedido actual para restaurar stock
    const [currentOrder] = await connection.query(
      'SELECT * FROM orders WHERE id = ?',
      [orderId]
    );
    
    if (currentOrder.length === 0) {
      await connection.rollback();
      return res.status(404).json({ error: 'Pedido no encontrado' });
    }
    
    // Obtener items actuales para restaurar stock
    const [currentItems] = await connection.query(
      'SELECT * FROM order_items WHERE order_id = ?',
      [orderId]
    );
    
    // Restaurar stock de items actuales
    for (const item of currentItems) {
      await connection.query(
        'UPDATE products SET stock = stock + ? WHERE id = ?',
        [item.quantity, item.product_id]
      );
    }
    
    // Eliminar items actuales
    await connection.query(
      'DELETE FROM order_items WHERE order_id = ?',
      [orderId]
    );
    
    // Calcular nuevo total
    let total = 0;
    const productIds = items.map(item => item.product_id);
    const [products] = await connection.query(
      'SELECT id, price FROM products WHERE id IN (?)',
      [productIds]
    );
    
    const productMap = {};
    products.forEach(p => productMap[p.id] = p);
    
    // Preparar nuevos items
    const orderItemsData = items.map(item => {
      const product = productMap[item.product_id];
      const itemTotal = product.price * item.quantity;
      total += itemTotal;
      return [orderId, item.product_id, item.quantity, product.price, itemTotal];
    });
    
    // Actualizar orden (mantener el status actual si no se proporciona uno nuevo)
    if (status) {
      await connection.query(
        'UPDATE orders SET total = ?, payment_method = ?, status = ? WHERE id = ?',
        [total, payment_method || 'Yape/Plin', status, orderId]
      );
    } else {
      await connection.query(
        'UPDATE orders SET total = ?, payment_method = ? WHERE id = ?',
        [total, payment_method || 'Yape/Plin', orderId]
      );
    }
    
    // Insertar nuevos items
    await connection.query(
      'INSERT INTO order_items (order_id, product_id, quantity, unit_price, total) VALUES ?',
      [orderItemsData]
    );
    
    // Actualizar stock con nuevas cantidades
    const stockUpdates = items.map(item => 
      `WHEN ${item.product_id} THEN stock - ${item.quantity}`
    ).join(' ');
    
    await connection.query(
      `UPDATE products 
       SET stock = CASE id ${stockUpdates} ELSE stock END 
       WHERE id IN (?)`,
      [productIds]
    );
    
    await connection.commit();
    
    res.json({ 
      message: 'Pedido actualizado exitosamente',
      total: total
    });
  } catch (error) {
    await connection.rollback();
    next(error);
  } finally {
    connection.release();
  }
});

router.put('/:id/status', authMiddleware, async (req, res, next) => {
  try {
    const { status } = req.body;
    
    await global.db.query(
      'UPDATE orders SET status = ? WHERE id = ?',
      [status, req.params.id]
    );
    
    res.json({ message: 'Order status updated successfully' });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/pdf', authMiddleware, async (req, res, next) => {
  try {
    const [orders] = await global.db.query(`
      SELECT o.*, c.* 
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
      WHERE o.id = ?
    `, [req.params.id]);
    
    if (orders.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }
    
    const [items] = await global.db.query(`
      SELECT oi.*, p.name, p.sku 
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    `, [req.params.id]);
    
    orders[0].items = items;
    
    const pdfBuffer = await generateOrderPDF(orders[0]);
    
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=order-${orders[0].order_id}.pdf`);
    res.send(pdfBuffer);
  } catch (error) {
    next(error);
  }
});

module.exports = router;