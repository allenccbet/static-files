#!/bin/bash

set -e

# ==========================================
# Nginx Domain + Wildcard Subdomain Proxy
# (HTTP only, no SSL)
# ==========================================

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo."
    exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
    echo "Nginx is not installed. Run your setup script first."
    exit 1
fi

echo ""
echo "=========================================="
echo "   Nginx Domain + Wildcard Proxy Setup"
echo "=========================================="
echo ""

# ------------------------------------------
# Ask for DOMAIN
# ------------------------------------------

read -r -p "Domain (e.g. example.com): " DOMAIN </dev/tty

# Clean input: protocol, path, wildcard prefix, trailing dot
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%%/*}"
DOMAIN="${DOMAIN#\*.}"
DOMAIN="${DOMAIN%.}"

if [ -z "$DOMAIN" ]; then
    echo "Error: Domain cannot be empty."
    exit 1
fi

# ------------------------------------------
# Ask for PORT
# ------------------------------------------

read -r -p "Port: " PORT </dev/tty

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "Error: Port must be a number between 1 and 65535."
    exit 1
fi

CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"
ENABLED_FILE="/etc/nginx/sites-enabled/$DOMAIN"

mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

# Don't silently clobber an existing config (e.g. one with SSL from certbot)
if [ -f "$CONFIG_FILE" ]; then
    echo ""
    echo "Warning: $CONFIG_FILE already exists (it may contain SSL settings)."
    read -r -p "Overwrite it? [y/N]: " CONFIRM </dev/tty
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%s)"
fi

# ------------------------------------------
# Create Nginx configuration
# ------------------------------------------

echo ""
echo "[+] Creating Nginx configuration..."

cat > "$CONFIG_FILE" <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN *.$DOMAIN;

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

ln -sf "$CONFIG_FILE" "$ENABLED_FILE"

# ------------------------------------------
# Test & reload
# ------------------------------------------

echo "[+] Testing Nginx configuration..."

if nginx -t >/dev/null 2>&1; then
    systemctl reload nginx
else
    echo "[✗] Nginx configuration failed."
    nginx -t
    rm -f "$ENABLED_FILE"
    exit 1
fi

echo ""
echo "=========================================="
echo "             SETUP COMPLETE"
echo "=========================================="
echo ""
echo "Domains : $DOMAIN, *.$DOMAIN"
echo "Proxy   : 127.0.0.1:$PORT"
echo "SSL     : Not configured (HTTP only)"
echo ""
echo "Note: add DNS records for $DOMAIN and *.$DOMAIN pointing to this server."
echo ""
echo "=========================================="
