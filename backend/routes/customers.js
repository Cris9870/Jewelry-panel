const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { body, validationResult } = require('express-validator');

router.get('/', authMiddleware, async (req, res, next) => {
  try {
    const { search } = req.query;
    let query = 'SELECT * FROM customers';
    let params = [];
    
    if (search) {
      query += ' WHERE name LIKE ? OR email LIKE ? OR phone LIKE ?';
      const searchPattern = `%${search}%`;
      params = [searchPattern, searchPattern, searchPattern];
    }
    
    query += ' ORDER BY created_at DESC';
    
    const [customers] = await global.db.query(query, params);
    res.json(customers);
  } catch (error) {
    next(error);
  }
});

router.get('/:id', authMiddleware, async (req, res, next) => {
  try {
    const [customers] = await global.db.query(
      'SELECT * FROM customers WHERE id = ?',
      [req.params.id]
    );
    
    if (customers.length === 0) {
      return res.status(404).json({ error: 'Customer not found' });
    }
    
    res.json(customers[0]);
  } catch (error) {
    next(error);
  }
});

router.post('/', authMiddleware, [
  body('name').notEmpty().withMessage('Name is required')
], async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { name, email, phone, address, dni } = req.body;
    
    const [result] = await global.db.query(
      'INSERT INTO customers (name, email, phone, address, dni) VALUES (?, ?, ?, ?, ?)',
      [name, email || null, phone || null, address || null, dni || null]
    );

    res.status(201).json({
      id: result.insertId,
      message: 'Customer created successfully'
    });
  } catch (error) {
    next(error);
  }
});

router.put('/:id', authMiddleware, async (req, res, next) => {
  try {
    const { name, email, phone, address, dni } = req.body;
    
    await global.db.query(
      'UPDATE customers SET name = ?, email = ?, phone = ?, address = ?, dni = ? WHERE id = ?',
      [name, email || null, phone || null, address || null, dni || null, req.params.id]
    );
    
    res.json({ message: 'Customer updated successfully' });
  } catch (error) {
    next(error);
  }
});

router.delete('/:id', authMiddleware, async (req, res, next) => {
  try {
    await global.db.query('DELETE FROM customers WHERE id = ?', [req.params.id]);
    res.json({ message: 'Customer deleted successfully' });
  } catch (error) {
    next(error);
  }
});

module.exports = router;