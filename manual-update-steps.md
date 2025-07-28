# Pasos para Actualizar el Panel de Joyería

## Método 1: Actualización Automática (Recomendado)

1. Conéctate a tu servidor por SSH
2. Ve al directorio del proyecto
3. Ejecuta el script de actualización:
```bash
bash deploy-updates.sh
```

## Método 2: Actualización Manual

### 1. Hacer backup de la base de datos
```bash
mysqldump -u tu_usuario -p jewelry_store > backup_$(date +%Y%m%d).sql
```

### 2. Obtener los últimos cambios
```bash
# Guardar cambios locales si los hay
git stash

# Obtener últimos cambios
git pull origin main

# Restaurar cambios locales
git stash pop
```

### 3. Aplicar la migración de base de datos
```bash
mysql -u tu_usuario -p jewelry_store < backend/migrations/005_create_company_settings.sql
```

### 4. Actualizar dependencias y construir
```bash
# Backend
cd backend
npm install

# Frontend
cd ../frontend
npm install
npm run build
cd ..
```

### 5. Reiniciar la aplicación
```bash
pm2 restart ecosystem.config.js
```

## Cambios Importantes Aplicados

### 1. **Mejoras en PDF**
- El SKU ahora aparece debajo del nombre del producto con fuente más pequeña
- Se removió el mensaje "Este documento no incluye IGV"
- La información de la empresa ahora es dinámica

### 2. **Nueva Página de Configuración**
- Accesible desde el menú lateral: "Configuración"
- Permite editar:
  - Nombre de la empresa
  - Email
  - Teléfono  
  - Dirección
  - Logo de la empresa

### 3. **Interfaz en Español**
- Todos los labels traducidos:
  - "All Orders" → "Pedidos"
  - "Products" → "Productos"
  - "Customers" → "Clientes"
  - "Log out" → "Cerrar sesión"
  - Y más...

### 4. **Búsqueda Mejorada**
- Los selectores de cliente y producto en el modal de pedidos ahora tienen búsqueda
- Filtrado en tiempo real mientras escribes

## Verificación Post-Actualización

1. Verifica que la aplicación esté corriendo:
```bash
pm2 status
```

2. Revisa los logs por si hay errores:
```bash
pm2 logs jewelry-panel --lines 50
```

3. Prueba las nuevas funcionalidades:
   - Crea un pedido y verifica el nuevo formato del PDF
   - Ve a Configuración y actualiza los datos de la empresa
   - Verifica que los cambios se reflejen en los PDFs

## En Caso de Problemas

Si algo sale mal, puedes restaurar el backup:
```bash
mysql -u tu_usuario -p jewelry_store < backup_YYYYMMDD.sql
```

Y volver a la versión anterior:
```bash
git reset --hard HEAD~1
```

## Notas de Seguridad

- **NUNCA** subas el archivo `.env` a GitHub
- El archivo `.gitignore` ya está configurado para ignorar archivos sensibles
- Mantén tus credenciales seguras y usa contraseñas fuertes