# Q'BellaJoyeria - Panel de Gestión de Joyería

Sistema completo de gestión de inventarios y punto de venta para joyerías, desarrollado con React y Node.js.

## 🚀 Instalación en Servidor

### Opción 1: Instalación Inicial
```bash
# Descargar y ejecutar el script de instalación
wget https://raw.githubusercontent.com/Cris9870/Jewelry-panel/main/initial-setup.sh
sudo bash initial-setup.sh
```

### Opción 2: Actualización de Instalación Existente
```bash
# En el servidor, dentro del directorio del proyecto
cd /opt/jewelry-panel
bash deploy-updates.sh
```

### Opción 3: Actualización Remota (desde tu computadora)
```bash
# Ejecutar desde tu máquina local
bash remote-update.sh
```

## 📋 Características Principales

- ✅ Gestión de productos con imágenes, SKU y control de stock
- ✅ Creación, edición y eliminación de productos individual y masiva (Excel/CSV)
- ✅ Gestión completa de clientes con búsqueda
- ✅ Sistema de pedidos con estados (Pendiente de Pago, Pagado, Cancelado)
- ✅ Múltiples métodos de pago (Yape/Plin, Efectivo, Transferencia, Tarjeta)
- ✅ Generación automática de PDF de pedidos (sin IGV)
- ✅ Control automático de stock al crear pedidos
- ✅ Dashboard con estadísticas de ventas
- ✅ Configuración dinámica de datos de la empresa
- ✅ Interfaz visual y amigable completamente en español

## 🛠️ Tecnologías

- **Frontend**: React + TypeScript + Vite
- **Backend**: Node.js + Express
- **Base de Datos**: MySQL
- **Servidor**: Nginx + PM2
- **PDF**: PDFKit

## 📦 Estructura del Proyecto

```
/opt/jewelry-panel/
├── backend/
│   ├── routes/          # Rutas de la API
│   ├── middleware/      # Autenticación y validaciones
│   ├── utils/          # Utilidades (generación PDF, etc)
│   ├── migrations/     # Scripts de base de datos
│   └── uploads/        # Imágenes de productos
├── frontend/
│   ├── src/            # Código fuente React
│   └── dist/           # Build de producción
└── ecosystem.config.js # Configuración PM2
```

## 📄 Funcionalidades Detalladas

### Gestión de Productos
- Información completa: nombre, SKU, precio, categoría, stock
- Subida de imágenes
- Carga masiva mediante CSV
- Control de stock en tiempo real

### Sistema de Pedidos
- ID único automático
- Asociación con cliente o anónimo
- Lista de productos con precios y totales
- Descuento automático de stock
- Validación de stock disponible

### Generación de PDF
- Datos de la empresa configurables
- Lista detallada de productos
- Información del cliente
- Formato profesional sin IGV

### Panel Principal
- Total de ventas recaudado
- Cantidad de pedidos
- Órdenes pendientes/completadas/canceladas
- Gráficos de estadísticas

## 🔧 Configuración Post-Instalación

1. **Base de Datos**: Editar credenciales en `/opt/jewelry-panel/backend/.env`
2. **Empresa**: Configurar datos desde el menú "Configuración"
3. **Usuario**: Cambiar contraseña por defecto (admin/admin123)

## 📝 Scripts Disponibles

- `deploy-updates.sh`: Actualiza el proyecto desde GitHub
- `initial-setup.sh`: Instalación completa desde cero
- `remote-update.sh`: Actualización remota vía SSH

## 🔐 Seguridad

- Los archivos `.env` no se suben al repositorio
- Backup automático antes de actualizaciones
- Autenticación JWT para todas las operaciones
- Validación de permisos en cada endpoint

## 📱 Compatibilidad

- Diseñado para uso en escritorio
- Compatible con navegadores modernos
- Optimizado para gestión administrativa

## 👥 Uso

Esta aplicación está diseñada para ser utilizada por el administrador de la tienda, no por clientes finales. La interfaz es intuitiva y no requiere conocimientos técnicos.

---

**Repositorio**: https://github.com/Cris9870/Jewelry-panel  
**Ubicación en servidor**: /opt/jewelry-panel/