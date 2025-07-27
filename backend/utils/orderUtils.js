const puppeteer = require('puppeteer');
const moment = require('moment');

function generateOrderId() {
  const timestamp = Date.now().toString(36);
  const randomStr = Math.random().toString(36).substring(2, 7);
  return `ORD-${timestamp.toUpperCase()}-${randomStr.toUpperCase()}`;
}

async function generateOrderPDF(order) {
  const browser = await puppeteer.launch({ headless: 'new' });
  const page = await browser.newPage();
  
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body {
          font-family: Arial, sans-serif;
          margin: 0;
          padding: 20px;
        }
        .header {
          text-align: center;
          margin-bottom: 30px;
        }
        .company-info {
          margin-bottom: 20px;
        }
        .order-info {
          display: flex;
          justify-content: space-between;
          margin-bottom: 20px;
        }
        .customer-info {
          margin-bottom: 30px;
        }
        table {
          width: 100%;
          border-collapse: collapse;
          margin-bottom: 20px;
        }
        th, td {
          border: 1px solid #ddd;
          padding: 8px;
          text-align: left;
        }
        th {
          background-color: #f2f2f2;
        }
        .total {
          text-align: right;
          font-size: 18px;
          font-weight: bold;
          margin-top: 20px;
        }
        .footer {
          margin-top: 50px;
          text-align: center;
          color: #666;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>COMPROBANTE DE PEDIDO</h1>
      </div>
      
      <div class="company-info">
        <h2>Joyería Luxora</h2>
        <p>Dirección: Av. Principal 123, Lima</p>
        <p>Teléfono: (01) 123-4567</p>
        <p>Email: info@joyerialuxora.com</p>
      </div>
      
      <div class="order-info">
        <div>
          <p><strong>N° de Pedido:</strong> ${order.order_id}</p>
          <p><strong>Fecha:</strong> ${moment(order.created_at).format('DD/MM/YYYY HH:mm')}</p>
        </div>
        <div>
          <p><strong>Estado:</strong> ${order.status}</p>
          <p><strong>Método de Pago:</strong> ${order.payment_method}</p>
        </div>
      </div>
      
      <div class="customer-info">
        <h3>Datos del Cliente</h3>
        <p><strong>Nombre:</strong> ${order.customer_name || order.name || 'Anónimo'}</p>
        ${order.dni ? `<p><strong>DNI:</strong> ${order.dni}</p>` : ''}
        ${order.phone ? `<p><strong>Teléfono:</strong> ${order.phone}</p>` : ''}
        ${order.email ? `<p><strong>Email:</strong> ${order.email}</p>` : ''}
        ${order.address ? `<p><strong>Dirección:</strong> ${order.address}</p>` : ''}
      </div>
      
      <h3>Detalle del Pedido</h3>
      <table>
        <thead>
          <tr>
            <th>Producto</th>
            <th>SKU</th>
            <th>Precio Unitario</th>
            <th>Cantidad</th>
            <th>Total</th>
          </tr>
        </thead>
        <tbody>
          ${order.items.map(item => `
            <tr>
              <td>${item.name}</td>
              <td>${item.sku}</td>
              <td>S/ ${parseFloat(item.unit_price).toFixed(2)}</td>
              <td>${item.quantity}</td>
              <td>S/ ${parseFloat(item.total).toFixed(2)}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
      
      <div class="total">
        <p>TOTAL: S/ ${parseFloat(order.total).toFixed(2)}</p>
      </div>
      
      <div class="footer">
        <p>¡Gracias por su compra!</p>
        <p>Este documento no incluye IGV</p>
      </div>
    </body>
    </html>
  `;
  
  await page.setContent(html);
  const pdf = await page.pdf({ format: 'A4' });
  
  await browser.close();
  
  return pdf;
}

module.exports = {
  generateOrderId,
  generateOrderPDF
};