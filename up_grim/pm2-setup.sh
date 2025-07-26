#!/bin/bash
# UP.GRIM.SO PM2 Setup Script
# Replaces Gunicorn with PM2 for better process management

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "💀 Setting up UP.GRIM.SO with PM2 (no more Gunicorn!)..."

# Stop and disable the old systemd service
echo "🗡️ Stopping old Gunicorn systemd service..."
systemctl stop up-grim-so 2>/dev/null || true
systemctl disable up-grim-so 2>/dev/null || true

# Remove old systemd service file
rm -f /etc/systemd/system/up-grim-so.service
systemctl daemon-reload

# Ensure virtual environment exists
if [[ ! -d "venv" ]]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv venv
fi

# Install dependencies
echo "📦 Installing Python dependencies..."
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Create log directory
mkdir -p logs
touch logs/pm2-error.log logs/pm2-out.log logs/pm2-combined.log

# Set permissions
chmod 755 app.py
chmod 755 pm2-setup.sh
chmod 644 ecosystem.config.js
chmod 755 logs
chmod 644 logs/*.log

# Test the application
echo "🧪 Testing Flask application..."
export FLASK_APP=app.py
export PORT=4745
python3 -c "from app import app; print('✅ Flask app loads successfully on port 4745')"

# Start with PM2
echo "🚀 Starting UP.GRIM.SO with PM2..."
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Setup PM2 startup script
pm2 startup

echo ""
echo "✅ UP.GRIM.SO PM2 setup complete!"
echo ""
echo "PM2 Commands:"
echo "  pm2 status                    # Check status"
echo "  pm2 logs up-grim-so          # View logs"
echo "  pm2 restart up-grim-so       # Restart service"
echo "  pm2 stop up-grim-so          # Stop service"
echo "  pm2 delete up-grim-so        # Remove from PM2"
echo ""
echo "Service is now running on: http://localhost:4745"
echo "Health check: curl http://localhost:4745/health"
echo ""
echo "💀 Death is now managed by PM2 instead of that awful Gunicorn!" 