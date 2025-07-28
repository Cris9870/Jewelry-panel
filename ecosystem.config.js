require('dotenv').config({ path: './backend/.env' });

module.exports = {
  apps: [{
    name: 'jewelry-backend',
    script: './backend/server.js',
    instances: 'max', // Usar todos los cores disponibles
    exec_mode: 'cluster', // Modo cluster para mejor rendimiento
    cwd: './backend', // Directorio de trabajo
    env: {
      NODE_ENV: 'production',
      PORT: process.env.PORT || 5000,
      DB_HOST: process.env.DB_HOST || '127.0.0.1',
      DB_USER: process.env.DB_USER,
      DB_PASSWORD: process.env.DB_PASSWORD,
      DB_NAME: process.env.DB_NAME,
      JWT_SECRET: process.env.JWT_SECRET
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: process.env.PORT || 5000,
      DB_HOST: process.env.DB_HOST || '127.0.0.1',
      DB_USER: process.env.DB_USER,
      DB_PASSWORD: process.env.DB_PASSWORD,
      DB_NAME: process.env.DB_NAME,
      JWT_SECRET: process.env.JWT_SECRET
    },
    error_file: '../logs/err.log',
    out_file: '../logs/out.log',
    log_file: '../logs/combined.log',
    time: true,
    max_memory_restart: '500M', // Reiniciar si usa más de 500MB
    watch: false,
    ignore_watch: ['node_modules', 'logs', 'uploads'],
    max_restarts: 10,
    min_uptime: '5s',
    autorestart: true,
    cron_restart: '0 0 * * *', // Reiniciar diariamente a medianoche
    // Graceful reload
    kill_timeout: 5000,
    wait_ready: true,
    listen_timeout: 3000
  }]
};