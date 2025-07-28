const PDFDocument = require('pdfkit');
const moment = require('moment');

function generateOrderId() {
  const timestamp = Date.now().toString(36);
  const randomStr = Math.random().toString(36).substring(2, 7);
  return `ORD-${timestamp.toUpperCase()}-${randomStr.toUpperCase()}`;
}

async function generateOrderPDF(order) {
  return new Promise(async (resolve, reject) => {
    try {
      // Get company settings
      let companyInfo = {
        name: 'Q\'BellaJoyeria',
        address: 'Av. Principal 123, Lima',
        phone: '(01) 123-4567',
        email: 'info@qbellajoyeria.com'
      };
      
      try {
        const [settings] = await global.db.query('SELECT * FROM company_settings LIMIT 1');
        if (settings.length > 0) {
          companyInfo = settings[0];
        }
      } catch (error) {
        console.error('Error fetching company settings:', error);
      }

      const doc = new PDFDocument({
        size: 'A4',
        margin: 50
      });

      const buffers = [];
      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => {
        const pdfBuffer = Buffer.concat(buffers);
        resolve(pdfBuffer);
      });

      // Header
      doc.fontSize(20)
         .text('COMPROBANTE DE PEDIDO', { align: 'center' })
         .moveDown();

      // Company info
      doc.fontSize(16)
         .text(companyInfo.name, { align: 'left' })
         .fontSize(10)
         .text(`Dirección: ${companyInfo.address}`)
         .text(`Teléfono: ${companyInfo.phone}`)
         .text(`Email: ${companyInfo.email}`)
         .moveDown();

      // Order info
      doc.fontSize(12)
         .text(`N° de Pedido: ${order.order_id}`)
         .text(`Fecha: ${moment(order.created_at).format('DD/MM/YYYY HH:mm')}`)
         .text(`Estado: ${order.status}`)
         .text(`Método de Pago: ${order.payment_method}`)
         .moveDown();

      // Customer info
      doc.fontSize(14)
         .text('Datos del Cliente', { underline: true })
         .fontSize(10)
         .text(`Nombre: ${order.customer_name || order.name || 'Anónimo'}`);
      
      if (order.dni) doc.text(`DNI: ${order.dni}`);
      if (order.phone) doc.text(`Teléfono: ${order.phone}`);
      if (order.email) doc.text(`Email: ${order.email}`);
      if (order.address) doc.text(`Dirección: ${order.address}`);
      
      doc.moveDown();

      // Products table header
      doc.fontSize(14)
         .text('Detalle del Pedido', { underline: true })
         .moveDown();

      // Table headers
      const tableTop = doc.y;
      const itemX = 50;
      const priceX = 320;
      const quantityX = 400;
      const totalX = 450;

      doc.fontSize(10)
         .text('Producto', itemX, tableTop, { bold: true })
         .text('Precio Unit.', priceX, tableTop)
         .text('Cant.', quantityX, tableTop)
         .text('Total', totalX, tableTop);

      // Draw line under headers
      doc.moveTo(50, tableTop + 15)
         .lineTo(520, tableTop + 15)
         .stroke();

      // Products
      let yPosition = tableTop + 25;
      
      if (order.items && order.items.length > 0) {
        order.items.forEach(item => {
          // Product name
          doc.fontSize(9)
             .text(item.name || '', itemX, yPosition, { width: 250 });
          
          // SKU below product name with smaller font
          if (item.sku) {
            doc.fontSize(7)
               .fillColor('#666666')
               .text(`(SKU: ${item.sku})`, itemX, yPosition + 12, { width: 250 })
               .fillColor('black');
          }
          
          // Price, quantity and total on same line as product name
          doc.fontSize(9)
             .text(`S/ ${parseFloat(item.unit_price).toFixed(2)}`, priceX, yPosition)
             .text(item.quantity.toString(), quantityX, yPosition)
             .text(`S/ ${parseFloat(item.total).toFixed(2)}`, totalX, yPosition);
          
          yPosition += item.sku ? 35 : 25; // More space if SKU is present
        });
      }

      // Total
      doc.moveTo(50, yPosition)
         .lineTo(520, yPosition)
         .stroke();

      doc.fontSize(14)
         .text(`TOTAL: S/ ${parseFloat(order.total).toFixed(2)}`, 380, yPosition + 10, { bold: true });

      // Footer
      doc.fontSize(10)
         .text('¡Gracias por su compra!', 50, doc.page.height - 100, { align: 'center' });

      // Finalize PDF
      doc.end();
    } catch (error) {
      reject(error);
    }
  });
}

module.exports = {
  generateOrderId,
  generateOrderPDF
};