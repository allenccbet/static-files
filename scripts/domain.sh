#!/bin/bash

set -e

# ==========================================
# Nginx + SSL Domain Setup
# ==========================================

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo."
    exit 1
fi

echo ""
echo "=========================================="
echo "       Nginx + SSL Domain Setup"
echo "=========================================="
echo ""

# ------------------------------------------
# Detect package manager
# ------------------------------------------

if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt-get"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
else
    echo "Unsupported Linux distribution."
    exit 1
fi

# ------------------------------------------
# Install Nginx if not installed
# ------------------------------------------

if command -v nginx >/dev/null 2>&1; then
    echo "[✓] Nginx already installed."
else
    echo "[+] Installing Nginx..."

    if [ "$PKG_MANAGER" = "apt-get" ]; then
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y nginx >/dev/null
    else
        $PKG_MANAGER install -y nginx >/dev/null
    fi

    echo "[✓] Nginx installed."
fi

# ------------------------------------------
# Install Certbot if not installed
# ------------------------------------------

if command -v certbot >/dev/null 2>&1; then
    echo "[✓] Certbot already installed."
else
    echo "[+] Installing Certbot..."

    if [ "$PKG_MANAGER" = "apt-get" ]; then
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx >/dev/null
    else
        $PKG_MANAGER install -y certbot >/dev/null
    fi

    echo "[✓] Certbot installed."
fi

# ------------------------------------------
# Start Nginx
# ------------------------------------------

systemctl enable nginx >/dev/null 2>&1 || true
systemctl start nginx >/dev/null 2>&1 || true

# ------------------------------------------
# Ask for DOMAIN
# ------------------------------------------

echo ""
read -r -p "Domain: " DOMAIN </dev/tty

# Remove protocol
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"

# Remove path
DOMAIN="${DOMAIN%%/*}"

# Remove trailing dot
DOMAIN="${DOMAIN%.}"

if [ -z "$DOMAIN" ]; then
    echo "Error: Domain cannot be empty."
    exit 1
fi

# ------------------------------------------
# Ask for PORT
# ------------------------------------------

echo ""
read -r -p "Port: " PORT </dev/tty

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "Error: Port must be a number."
    exit 1
fi

if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "Error: Port must be between 1 and 65535."
    exit 1
fi

# ------------------------------------------
# Configuration paths
# ------------------------------------------

CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"
ENABLED_FILE="/etc/nginx/sites-enabled/$DOMAIN"

# ------------------------------------------
# Create directories
# ------------------------------------------

mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

# ------------------------------------------
# Create Nginx configuration
# ------------------------------------------

echo ""
echo "[+] Creating Nginx configuration..."

cat > "$CONFIG_FILE" <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# ------------------------------------------
# Enable site
# ------------------------------------------

ln -sf "$CONFIG_FILE" "$ENABLED_FILE"

# Remove default Nginx site
if [ -e /etc/nginx/sites-enabled/default ]; then
    rm -f /etc/nginx/sites-enabled/default
fi

# ------------------------------------------
# Test Nginx
# ------------------------------------------

echo "[+] Testing Nginx configuration..."

if nginx -t >/dev/null 2>&1; then
    echo "[✓] Nginx configuration is valid."
else
    echo "[✗] Nginx configuration failed."
    nginx -t
    exit 1
fi

systemctl reload nginx

echo "[✓] Nginx configured."
echo ""

# ------------------------------------------
# Generate SSL
# ------------------------------------------

echo "[+] Generating SSL certificate..."
echo ""

certbot --nginx \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    --register-unsafely-without-email \
    --redirect

# ------------------------------------------
# Final test
# ------------------------------------------

echo ""
echo "[+] Testing final Nginx configuration..."

if nginx -t >/dev/null 2>&1; then

    systemctl reload nginx

    echo ""
    echo "=========================================="
    echo "             SETUP COMPLETE"
    echo "=========================================="
    echo ""
    echo "Domain : $DOMAIN"
    echo "Port   : $PORT"
    echo ""
    echo "URL    : https://$DOMAIN"
    echo ""
    echo "SSL    : Enabled"
    echo "Proxy  : 127.0.0.1:$PORT"
    echo ""
    echo "=========================================="

else

    echo ""
    echo "[✗] Final Nginx configuration failed."
    nginx -t
    exit 1

fi
