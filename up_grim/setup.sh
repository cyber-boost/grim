#!/bin/bash
# UP.GRIM.SO Setup Script
# Sets up the version check service with virtual environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "💀 Setting up UP.GRIM.SO version check service..."

# Create virtual environment
if [[ ! -d "venv" ]]; then
    echo "🗡️ Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate and install dependencies
echo "📦 Installing Python dependencies..."
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Create log directory
mkdir -p logs
touch logs/up_grim.log logs/access.log logs/error.log

# Set permissions
chmod 755 app.py
chmod 644 gunicorn.conf.py
chmod 755 logs
chmod 644 logs/*.log

# Test the application
echo "🧪 Testing Flask application..."
export FLASK_APP=app.py
python3 -c "from app import app; print('✅ Flask app loads successfully')"

# Enable and start systemd service
echo "⚙️ Setting up systemd service..."
systemctl daemon-reload
systemctl enable up-grim-so.service

echo ""
echo "✅ UP.GRIM.SO setup complete!"
echo ""
echo "To start the service:"
echo "  sudo systemctl start up-grim-so"
echo ""
echo "To check status:"
echo "  sudo systemctl status up-grim-so"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u up-grim-so -f"
echo ""
echo "Service will run on: http://localhost:4745"
echo "Health check: curl http://localhost:4745/health"
echo ""
echo "💀 Death is ready to monitor version updates!"