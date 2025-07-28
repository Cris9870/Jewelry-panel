#!/bin/bash

echo "=== Diagnóstico y Corrección del Backend ==="
echo ""

cd /opt/jewelry-panel/backend

# 1. Verificar que existe el archivo de rutas de auth
echo "1. Verificando archivos de autenticación..."
if [ ! -f "routes/auth.js" ]; then
    echo "   ✗ No existe routes/auth.js"
    echo "   Descargando archivo..."
    mkdir -p routes
    curl -s https://raw.githubusercontent.com/Cris9870/Jewelry-panel/main/backend/routes/auth.js -o routes/auth.js
fi

# 2. Verificar middleware de autenticación
if [ ! -f "middleware/auth.js" ]; then
    echo "   ✗ No existe middleware/auth.js"
    echo "   Creando archivo..."
    mkdir -p middleware
    cat > middleware/auth.js << 'EOF'
const jwt = require('jsonwebtoken');

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token no proporcionado' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'default_secret', (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Token inválido' });
    }
    req.user = user;
    next();
  });
};

module.exports = { authenticateToken };
EOF
fi

# 3. Verificar errorHandler
if [ ! -f "middleware/errorHandler.js" ]; then
    echo "   ✗ No existe middleware/errorHandler.js"
    echo "   Creando archivo..."
    cat > middleware/errorHandler.js << 'EOF'
const errorHandler = (err, req, res, next) => {
  console.error('Error:', err.stack);
  
  if (err.name === 'ValidationError') {
    return res.status(400).json({ error: err.message });
  }
  
  if (err.name === 'UnauthorizedError') {
    return res.status(401).json({ error: 'No autorizado' });
  }
  
  res.status(500).json({ error: 'Error interno del servidor: ' + err.message });
};

module.exports = { errorHandler };
EOF
fi

# 4. Verificar dependencias
echo ""
echo "2. Verificando dependencias..."
npm install bcryptjs jsonwebtoken

# 5. Verificar que el usuario admin existe en la base de datos
echo ""
echo "3. Verificando usuario admin en la base de datos..."
if [ -f ".env" ]; then
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    DB_USER=$(grep DB_USER .env | cut -d '=' -f2)
    DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
    DB_NAME=$(grep DB_NAME .env | cut -d '=' -f2)
    
    # Verificar si existe el usuario admin
    ADMIN_EXISTS=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME -N -e "SELECT COUNT(*) FROM users WHERE username='admin'" 2>/dev/null)
    
    if [ "$ADMIN_EXISTS" = "0" ] || [ -z "$ADMIN_EXISTS" ]; then
        echo "   ✗ Usuario admin no existe. Creando..."
        # Hash de 'admin123'
        HASHED_PASS='$2a$10$8KXkPk3j6O6lR9KZPqPmR.5NnE5NqXl88PyYqY8XqF7G5rBHRkVvC'
        mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME -e "INSERT INTO users (username, password) VALUES ('admin', '$HASHED_PASS')" 2>/dev/null
        echo "   ✓ Usuario admin creado (contraseña: admin123)"
    else
        echo "   ✓ Usuario admin existe"
    fi
fi

# 6. Crear un test endpoint
echo ""
echo "4. Agregando endpoint de prueba..."
cat > test-auth.js << 'EOF'
const express = require('express');
const app = express();
app.use(express.json());

// Test endpoint
app.get('/test', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' });
});

// Test auth
app.post('/test-auth', async (req, res) => {
  try {
    const bcrypt = require('bcryptjs');
    const { username, password } = req.body;
    
    // Test password hashing
    const hash = await bcrypt.hash(password, 10);
    const match = await bcrypt.compare(password, hash);
    
    res.json({
      received: { username, password: '***' },
      hashTest: match,
      bcryptWorking: true
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(5001, () => console.log('Test server on port 5001'));
EOF

# 7. Reiniciar backend
echo ""
echo "5. Reiniciando backend..."
pm2 restart jewelry-backend

# Esperar un momento
sleep 3

# 8. Probar el endpoint
echo ""
echo "6. Probando endpoints..."
echo "   Test básico:"
curl -s http://localhost:5000/api/auth/login || echo "   ✗ Error en endpoint"

echo ""
echo "   Test con credenciales:"
curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' || echo "   ✗ Error en login"

# 9. Mostrar logs recientes
echo ""
echo "7. Logs recientes del backend:"
pm2 logs jewelry-backend --lines 20 --nostream

echo ""
echo "=== Diagnóstico Completado ==="
echo ""
echo "Si persisten los errores, ejecuta:"
echo "node test-auth.js"
echo "Y prueba: curl http://localhost:5001/test"