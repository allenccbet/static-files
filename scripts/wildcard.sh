#!/bin/bash

set -e

# ==========================================================
# Nginx Wildcard Subdomain Proxy (*.$DOMAIN) with SSL & HTTP
# ==========================================================

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo."
    exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
    echo "Nginx is not installed. Run your setup script first."
    exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
    echo "OpenSSL is not installed. Install it first (apt install openssl)."
    exit 1
fi

echo ""
echo "=========================================================="
echo "    Nginx Wildcard Subdomain (*.domain) Proxy Setup"
echo "=========================================================="
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
SSL_DIR="/etc/ssl/$DOMAIN"

mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled "$SSL_DIR"

# Don't silently clobber an existing config
if [ -f "$CONFIG_FILE" ]; then
    echo ""
    echo "Warning: $CONFIG_FILE already exists."
    read -r -p "Overwrite it? [y/N]: " CONFIRM </dev/tty
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%s)"
fi

# ------------------------------------------
# Generate Wildcard SSL Certificate (*.$DOMAIN)
# ------------------------------------------

echo ""
echo "[+] Generating 10-year Wildcard SSL certificate for *.$DOMAIN..."

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "$SSL_DIR/privkey.pem" \
    -out "$SSL_DIR/fullchain.pem" \
    -subj "/CN=*.$DOMAIN" >/dev/null 2>&1

chmod 600 "$SSL_DIR/privkey.pem"
chmod 644 "$SSL_DIR/fullchain.pem"

# Optional Let's Encrypt SSL tuning include lines if present on the server
SSL_INCLUDES=""
if [ -f /etc/letsencrypt/options-ssl-nginx.conf ]; then
    SSL_INCLUDES="$SSL_INCLUDES
    include /etc/letsencrypt/options-ssl-nginx.conf;"
fi
if [ -f /etc/letsencrypt/ssl-dhparams.pem ]; then
    SSL_INCLUDES="$SSL_INCLUDES
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;"
fi

# ------------------------------------------
# Create Nginx configuration
# ------------------------------------------

echo "[+] Creating Nginx configuration..."

cat > "$CONFIG_FILE" <<EOF
# HTTPS (Port 443) - handles Cloudflare "Full" SSL mode
server {
    server_name *.$DOMAIN;

    listen [::]:443 ssl;
    listen 443 ssl;
    ssl_certificate $SSL_DIR/fullchain.pem;
    ssl_certificate_key $SSL_DIR/privkey.pem;$SSL_INCLUDES

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

# HTTP (Port 80) - handles Cloudflare "Flexible" SSL mode
server {
    listen 80;
    listen [::]:80;

    server_name *.$DOMAIN;

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
    echo "[✗] Nginx configuration test failed."
    nginx -t
    rm -f "$ENABLED_FILE"
    exit 1
fi

echo ""
echo "=========================================================="
echo "                     SETUP COMPLETE"
echo "=========================================================="
echo ""
echo "Wildcard Subdomain : *.$DOMAIN (Apex domain ignored)"
echo "Proxy Target       : 127.0.0.1:$PORT"
echo "SSL Cert Path      : $SSL_DIR/fullchain.pem"
echo "Cloudflare Ready   : Supports both 'Flexible' (Port 80) and 'Full' (Port 443)"
echo ""
echo "Note: Ensure DNS has a wildcard CNAME or A record (*.$DOMAIN) pointed here."
echo ""
echo "=========================================================="
