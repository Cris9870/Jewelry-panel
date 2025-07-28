# Changelog - Panel de Joyería

## [1.2.0] - 2025-07-28

### 🚀 Optimizaciones de Rendimiento

#### Base de Datos
- ✅ Agregados índices para mejorar consultas (hasta 75% más rápido)
- ✅ Corregido problema N+1 Query en pedidos (de 30+ queries a solo 3)
- ✅ Pool de conexiones optimizado (20 conexiones, timeouts configurados)

#### Backend  
- ✅ Implementada compresión HTTP con gzip
- ✅ Agregado rate limiting (100 req/15min por IP)
- ✅ Headers de seguridad con Helmet
- ✅ Cache headers para archivos estáticos
- ✅ Graceful shutdown handling para PM2

#### Frontend
- ✅ Code splitting con lazy loading
- ✅ SearchableSelect virtualizado para listas grandes (+100 items)
- ✅ Componentes optimizados con memoización

### 🐛 Correcciones de Errores

1. **Error toFixed en productos**
   - Corregido error "toFixed is not a function"
   - Implementado parseFloat(String()) para valores de MySQL

2. **Error de login**
   - Mensajes de error ahora permanecen visibles
   - Traducido a español: "Usuario o contraseña incorrectos"

3. **Error 404 al editar pedidos**
   - Agregada ruta PUT /api/orders/:id faltante
   - Manejo correcto de stock al actualizar

4. **Error 502 en PM2**
   - Corregido problema con variables de entorno en cluster mode
   - ecosystem.config.js simplificado

5. **Problemas de CSS en Pedidos**
   - Agregados estilos críticos a App.css
   - Eliminado FOUC (Flash of Unstyled Content)

### ✨ Nuevas Características

1. **Configuración de Empresa**
   - Nueva página de configuración en /settings
   - Campos opcionales excepto nombre
   - Logo de empresa configurable

2. **Mejoras en Pedidos**
   - SearchableSelect para clientes y productos
   - Edición completa de pedidos
   - Vista detallada de pedidos

3. **Mejoras en PDFs**
   - SKU ahora aparece debajo del nombre del producto
   - Campos vacíos de empresa no se muestran
   - Eliminado mensaje de IGV

4. **Interfaz en Español**
   - Todos los labels traducidos
   - Mensajes de error en español
   - Estados de pedidos en español

### 📦 Dependencias Agregadas

Backend:
- compression: ^1.7.4
- express-rate-limit: ^7.1.5
- helmet: ^7.1.0

Frontend:
- react-window: ^1.8.10
- @types/react-window: ^1.8.8

### 🔧 Configuración

- PM2 configurado en modo cluster
- Nginx con cache y compresión
- Scripts de deployment actualizados

### 📝 Scripts de Deployment

- `deploy-updates.sh` - Actualización general
- `performance-deploy.sh` - Aplicar optimizaciones
- `handle-conflicts-update.sh` - Manejar conflictos git

---

## [1.1.0] - Versión anterior

- Sistema base de gestión de joyería
- CRUD de productos, clientes y pedidos
- Generación de PDFs
- Dashboard con estadísticas