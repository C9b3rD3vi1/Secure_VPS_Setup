#!/bin/bash

###############################################################################
# SSL/TLS SETUP SCRIPT WITH LET'S ENCRYPT
# Purpose: Automated SSL certificate installation and auto-renewal
# Usage: sudo bash 2_ssl_setup.sh
# Author: Simux Tech
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}SSL/TLS SETUP WITH LET'S ENCRYPT${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Check if Nginx or Apache is installed
WEBSERVER="none"
if command -v nginx &> /dev/null; then
    WEBSERVER="nginx"
elif command -v apache2 &> /dev/null; then
    WEBSERVER="apache2"
else
    echo -e "${RED}Error: Neither Nginx nor Apache is installed${NC}"
    echo -e "${YELLOW}Would you like to install Nginx? (y/n)${NC}"
    read -p "> " INSTALL_NGINX
    if [ "$INSTALL_NGINX" = "y" ]; then
        apt-get update -qq
        apt-get install -y nginx
        WEBSERVER="nginx"
        echo -e "${GREEN}✓ Nginx installed${NC}"
    else
        exit 1
    fi
fi

echo -e "${GREEN}Detected web server: $WEBSERVER${NC}"
echo ""

# Get domain information
echo -e "${YELLOW}Enter your domain name (e.g., example.com):${NC}"
read -p "> " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: Domain name is required${NC}"
    exit 1
fi

echo -e "${YELLOW}Enter your email for SSL renewal notifications:${NC}"
read -p "> " EMAIL

if [ -z "$EMAIL" ]; then
    echo -e "${RED}Error: Email is required${NC}"
    exit 1
fi

# Confirm details
echo ""
echo -e "${YELLOW}Please confirm:${NC}"
echo "  Domain: $DOMAIN"
echo "  Email: $EMAIL"
echo "  Web server: $WEBSERVER"
echo ""
read -p "Continue? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo "Aborted."
    exit 0
fi

# Install Certbot
echo -e "${YELLOW}[1/6] Installing Certbot and dependencies...${NC}"
apt-get update -qq
apt-get install -y certbot dnsutils

if [ "$WEBSERVER" = "nginx" ]; then
    apt-get install -y python3-certbot-nginx
else
    apt-get install -y python3-certbot-apache
fi

echo -e "${GREEN}✓ Certbot installed${NC}"
echo ""

# Verify DNS is pointing to this server
echo -e "${YELLOW}[2/6] Verifying DNS configuration...${NC}"
SERVER_IP=$(hostname -I | awk '{print $1}')
DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)

echo "Server IP: $SERVER_IP"
echo "Domain resolves to: $DOMAIN_IP"

if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
    echo -e "${RED}⚠ WARNING: Domain does not resolve to this server!${NC}"
    echo -e "${YELLOW}Make sure your domain's A record points to: $SERVER_IP${NC}"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ DNS configured correctly${NC}"
fi
echo ""

# Create basic web server config if needed
if [ "$WEBSERVER" = "nginx" ]; then
    echo -e "${YELLOW}[3/6] Configuring Nginx...${NC}"
    
    # Create basic server block if it doesn't exist
    if [ ! -f "/etc/nginx/sites-available/$DOMAIN" ]; then
        cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    
    root /var/www/$DOMAIN;
    index index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
        
        # Create web root
        mkdir -p /var/www/$DOMAIN
        echo "<h1>Welcome to $DOMAIN</h1><p>SSL is being configured...</p>" > /var/www/$DOMAIN/index.html
        chown -R www-data:www-data /var/www/$DOMAIN
        
        # Enable site
        ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
        
        # Test and reload Nginx
        nginx -t
        systemctl reload nginx
        
        echo -e "${GREEN}✓ Nginx configured${NC}"
    else
        echo -e "${YELLOW}Site configuration already exists${NC}"
    fi
fi

echo ""

# Obtain SSL certificate
echo -e "${YELLOW}[4/6] Obtaining SSL certificate from Let's Encrypt...${NC}"
echo -e "${YELLOW}This may take a minute...${NC}"

if [ "$WEBSERVER" = "nginx" ]; then
    certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect
else
    certbot --apache -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SSL certificate obtained successfully${NC}"
else
    echo -e "${RED}Error: Failed to obtain SSL certificate${NC}"
    exit 1
fi
echo ""

# Test auto-renewal
echo -e "${YELLOW}[5/6] Testing certificate auto-renewal...${NC}"
certbot renew --dry-run

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Auto-renewal is working${NC}"
else
    echo -e "${RED}⚠ Warning: Auto-renewal test failed${NC}"
fi
echo ""

# Add SSL hardening to Nginx config
if [ "$WEBSERVER" = "nginx" ]; then
    echo -e "${YELLOW}[6/6] Applying SSL hardening...${NC}"
    
    # Create SSL configuration snippet
    cat > /etc/nginx/snippets/ssl-params.conf << 'EOF'
# SSL Security Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;

# Security Headers
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;

resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
EOF

    # Add SSL params to site config if not already present
    if ! grep -q "ssl-params.conf" /etc/nginx/sites-available/$DOMAIN; then
        sed -i '/ssl_certificate/a\    include snippets/ssl-params.conf;' /etc/nginx/sites-available/$DOMAIN
    fi
    
    # Test and reload
    nginx -t && systemctl reload nginx
    
    echo -e "${GREEN}✓ SSL hardening applied${NC}"
fi

echo ""

# Summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}SSL SETUP COMPLETE!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Summary:"
echo -e "  ✓ SSL certificate installed for: $DOMAIN"
echo -e "  ✓ HTTPS redirect enabled"
echo -e "  ✓ Auto-renewal configured (runs twice daily)"
echo -e "  ✓ SSL security hardening applied"
echo ""
echo -e "${YELLOW}Certificate details:${NC}"
certbot certificates
echo ""
echo -e "${YELLOW}Testing your SSL:${NC}"
echo -e "  Visit: https://$DOMAIN"
echo -e "  Test at: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo -e "1. Verify your site loads correctly at https://$DOMAIN"
echo -e "2. Run: sudo bash 3_fail2ban_setup.sh"
echo -e "3. Run: sudo bash 4_firewall_setup.sh"
echo ""
echo -e "${GREEN}Auto-renewal will happen automatically. Check logs with:${NC}"
echo -e "  sudo journalctl -u certbot.timer"
echo ""
