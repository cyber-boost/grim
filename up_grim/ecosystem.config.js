module.exports = {
  apps: [{
    name: 'up-grim-so',
    script: 'app.py',
    interpreter: './venv/bin/python3',
    cwd: '/opt/reaper/up_grim',
    instances: 1,
    exec_mode: 'fork',
    env: {
      FLASK_APP: 'app.py',
      FLASK_ENV: 'production',
      PORT: 4745
    },
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_file: './logs/pm2-combined.log',
    time: true,
    max_memory_restart: '200M',
    watch: false,
    ignore_watch: ['logs', 'venv', '__pycache__'],
    kill_timeout: 5000,
    autorestart: true,
    max_restarts: 10,
    min_uptime: '10s'
  }]
}; 