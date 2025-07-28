module.exports = {
  apps: [{
    name: 'jewelry-backend',
    script: './backend/server.js',
    instances: 'max', // Usar todos los cores disponibles
    exec_mode: 'cluster', // Modo cluster para mejor rendimiento
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
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