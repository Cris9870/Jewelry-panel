#!/bin/bash

echo "==================================="
echo "Corrección completa de dependencias"
echo "==================================="

# 1. Instalar curl y otras herramientas básicas
echo "1. Instalando herramientas básicas..."
sudo apt update
sudo apt install -y curl wget software-properties-common

# 2. Eliminar versión antigua de Node.js
echo "2. Eliminando Node.js antiguo..."
sudo apt remove -y nodejs npm
sudo apt autoremove -y

# 3. Limpiar configuraciones anteriores
sudo rm -rf /usr/local/bin/npm /usr/local/share/man/man1/node* /usr/local/lib/dtrace/node.d
sudo rm -rf ~/.npm
sudo rm -rf /usr/local/lib/node*
sudo rm -rf /usr/local/include/node*
sudo rm -rf /usr/local/bin/node*

# 4. Instalar Node.js 18 correctamente
echo "3. Instalando Node.js 18 LTS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 5. Verificar instalación
echo "4. Verificando instalación..."
node_version=$(node -v 2>/dev/null)
npm_version=$(npm -v 2>/dev/null)

if [ -z "$node_version" ] || [ -z "$npm_version" ]; then
    echo "ERROR: Node.js no se instaló correctamente"
    echo "Intentando método alternativo..."
    
    # Método alternativo: instalar desde binarios
    cd /tmp
    wget https://nodejs.org/dist/v18.20.0/node-v18.20.0-linux-x64.tar.xz
    sudo tar -xJf node-v18.20.0-linux-x64.tar.xz -C /usr/local --strip-components=1
    
    # Crear enlaces simbólicos
    sudo ln -sf /usr/local/bin/node /usr/bin/node
    sudo ln -sf /usr/local/bin/npm /usr/bin/npm
    sudo ln -sf /usr/local/bin/npx /usr/bin/npx
fi

# 6. Verificar nuevamente
echo "5. Verificación final..."
echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

# 7. Instalar PM2
echo "6. Instalando PM2..."
sudo npm install -g pm2

echo "==================================="
echo "✓ Corrección completada"
echo "==================================="
echo "Ahora puedes ejecutar el script de despliegue"