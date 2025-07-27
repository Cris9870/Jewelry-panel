const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const xlsx = require('xlsx');
const { body, validationResult } = require('express-validator');

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/')
  },
  filename: function (req, file, cb) {
    cb(null, Date.now() + path.extname(file.originalname))
  }
});

const upload = multer({ storage: storage });

router.get('/', authMiddleware, async (req, res, next) => {
  try {
    const [products] = await global.db.query(`
      SELECT p.*, c.name as category_name 
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY p.created_at DESC
    `);
    res.json(products);
  } catch (error) {
    next(error);
  }
});

router.get('/:id', authMiddleware, async (req, res, next) => {
  try {
    const [products] = await global.db.query(
      'SELECT * FROM products WHERE id = ?',
      [req.params.id]
    );
    
    if (products.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    res.json(products[0]);
  } catch (error) {
    next(error);
  }
});

router.post('/', authMiddleware, upload.single('image'), [
  body('sku').notEmpty().withMessage('SKU is required'),
  body('name').notEmpty().withMessage('Name is required'),
  body('price').isFloat({ min: 0 }).withMessage('Price must be a positive number'),
  body('stock').isInt({ min: 0 }).withMessage('Stock must be a non-negative integer')
], async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { sku, name, price, category_id, attributes, stock } = req.body;
    const image_url = req.file ? `/uploads/${req.file.filename}` : null;

    const [result] = await global.db.query(
      'INSERT INTO products (sku, name, price, category_id, attributes, stock, image_url) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [sku, name, price, category_id || null, attributes || null, stock || 0, image_url]
    );

    res.status(201).json({
      id: result.insertId,
      message: 'Product created successfully'
    });
  } catch (error) {
    next(error);
  }
});

router.put('/:id', authMiddleware, upload.single('image'), async (req, res, next) => {
  try {
    const { sku, name, price, category_id, attributes, stock } = req.body;
    const productId = req.params.id;
    
    let updateQuery = 'UPDATE products SET sku = ?, name = ?, price = ?, category_id = ?, attributes = ?, stock = ?';
    let params = [sku, name, price, category_id || null, attributes || null, stock || 0];
    
    if (req.file) {
      updateQuery += ', image_url = ?';
      params.push(`/uploads/${req.file.filename}`);
    }
    
    updateQuery += ' WHERE id = ?';
    params.push(productId);
    
    await global.db.query(updateQuery, params);
    
    res.json({ message: 'Product updated successfully' });
  } catch (error) {
    next(error);
  }
});

router.delete('/:id', authMiddleware, async (req, res, next) => {
  try {
    await global.db.query('DELETE FROM products WHERE id = ?', [req.params.id]);
    res.json({ message: 'Product deleted successfully' });
  } catch (error) {
    next(error);
  }
});

router.post('/bulk-upload', authMiddleware, upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const workbook = xlsx.readFile(req.file.path);
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    const data = xlsx.utils.sheet_to_json(worksheet);

    const results = {
      success: 0,
      failed: 0,
      errors: []
    };

    for (const row of data) {
      try {
        await global.db.query(
          'INSERT INTO products (sku, name, price, category_id, attributes, stock) VALUES (?, ?, ?, ?, ?, ?)',
          [
            row.sku || row.SKU,
            row.name || row.Name || row.nombre,
            row.price || row.Price || row.precio,
            row.category_id || null,
            JSON.stringify(row.attributes || {}),
            row.stock || row.Stock || 0
          ]
        );
        results.success++;
      } catch (error) {
        results.failed++;
        results.errors.push({
          row: row,
          error: error.message
        });
      }
    }

    res.json(results);
  } catch (error) {
    next(error);
  }
});

router.get('/categories/all', authMiddleware, async (req, res, next) => {
  try {
    const [categories] = await global.db.query('SELECT * FROM categories ORDER BY name');
    res.json(categories);
  } catch (error) {
    next(error);
  }
});

module.exports = router;