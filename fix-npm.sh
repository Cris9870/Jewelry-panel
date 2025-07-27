#!/bin/bash

# Script para arreglar el problema de npm no encontrado

echo "Arreglando instalación de Node.js/npm..."

# Opción 1: Reinstalar Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verificar si funciona
if command -v npm &> /dev/null; then
    echo "✓ npm instalado correctamente"
    npm -v
    
    # Instalar PM2
    sudo npm install -g pm2
    echo "✓ PM2 instalado"
else
    echo "Intentando método alternativo con snap..."
    
    # Opción 2: Usar snap
    sudo snap install node --classic --channel=18
    sudo ln -sf /snap/bin/node /usr/bin/node
    sudo ln -sf /snap/bin/npm /usr/bin/npm
    sudo ln -sf /snap/bin/npx /usr/bin/npx
    
    # Instalar PM2 con snap
    /snap/bin/npm install -g pm2
fi

echo "Instalación completada. Continúa con el script de despliegue."