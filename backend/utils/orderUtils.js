const PDFDocument = require('pdfkit');
const moment = require('moment');

function generateOrderId() {
  const timestamp = Date.now().toString(36);
  const randomStr = Math.random().toString(36).substring(2, 7);
  return `ORD-${timestamp.toUpperCase()}-${randomStr.toUpperCase()}`;
}

async function generateOrderPDF(order) {
  return new Promise((resolve, reject) => {
    try {
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
         .text('Joyería Luxora', { align: 'left' })
         .fontSize(10)
         .text('Dirección: Av. Principal 123, Lima')
         .text('Teléfono: (01) 123-4567')
         .text('Email: info@joyerialuxora.com')
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
      const skuX = 200;
      const priceX = 280;
      const quantityX = 350;
      const totalX = 420;

      doc.fontSize(10)
         .text('Producto', itemX, tableTop, { bold: true })
         .text('SKU', skuX, tableTop)
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
          doc.fontSize(9)
             .text(item.name || '', itemX, yPosition)
             .text(item.sku || '', skuX, yPosition)
             .text(`S/ ${parseFloat(item.unit_price).toFixed(2)}`, priceX, yPosition)
             .text(item.quantity.toString(), quantityX, yPosition)
             .text(`S/ ${parseFloat(item.total).toFixed(2)}`, totalX, yPosition);
          
          yPosition += 20;
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
         .text('¡Gracias por su compra!', 50, doc.page.height - 100, { align: 'center' })
         .text('Este documento no incluye IGV', { align: 'center' });

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