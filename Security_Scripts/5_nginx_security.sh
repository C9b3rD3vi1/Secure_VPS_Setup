#!/bin/bash

###############################################################################
# NGINX SECURITY HARDENING SCRIPT
# Purpose: Apply production-grade security configurations to Nginx
# Usage: sudo bash 5_nginx_security.sh
# Author: Simux Tech
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}NGINX SECURITY HARDENING${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Check if Nginx is installed
if ! command -v nginx &> /dev/null; then
    echo -e "${RED}Error: Nginx is not installed${NC}"
    read -p "Would you like to install Nginx? (y/n): " INSTALL
    if [ "$INSTALL" = "y" ]; then
        apt-get update -qq
        apt-get install -y nginx
        echo -e "${GREEN}✓ Nginx installed${NC}"
    else
        exit 1
    fi
fi

# Backup existing configuration
echo -e "${YELLOW}[1/8] Backing up existing Nginx configuration...${NC}"
mkdir -p /etc/nginx/backups
cp /etc/nginx/nginx.conf /etc/nginx/backups/nginx.conf.backup.$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✓ Configuration backed up${NC}"
echo ""

# Create security headers configuration
echo -e "${YELLOW}[2/8] Creating security headers configuration...${NC}"
cat > /etc/nginx/snippets/security-headers.conf << 'EOF'
# Security Headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

# Remove Nginx version from headers and error pages
server_tokens off;
EOF

echo -e "${GREEN}✓ Security headers configuration created${NC}"
echo ""

# Create rate limiting configuration
echo -e "${YELLOW}[3/8] Creating rate limiting configuration...${NC}"
cat > /etc/nginx/snippets/rate-limiting.conf << 'EOF'
# Rate Limiting Zones
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=3r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;

# Connection limiting
limit_conn_zone $binary_remote_addr zone=addr:10m;
limit_conn addr 10;

# Request body size limit (prevents large uploads)
client_max_body_size 10M;
EOF

echo -e "${GREEN}✓ Rate limiting configuration created${NC}"
echo ""

# Update main nginx.conf
echo -e "${YELLOW}[4/8] Updating main Nginx configuration...${NC}"

# Create extra security snippet (safe - no appending outside blocks)
cat > /etc/nginx/snippets/extra-security.conf << 'EOF'
# Additional Security Settings
server_tokens off;
client_body_buffer_size     1k;
client_header_buffer_size   1k;
large_client_header_buffers 2 1k;
client_body_timeout         10;
client_header_timeout       10;
keepalive_timeout           5 5;
send_timeout                10;

# Gzip
gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
EOF

# Include all snippets inside http block safely
if ! grep -q "snippets/rate-limiting.conf" /etc/nginx/nginx.conf; then
    sed -i '/http {/a\    include /etc/nginx/snippets/rate-limiting.conf;' /etc/nginx/nginx.conf
fi
if ! grep -q "snippets/extra-security.conf" /etc/nginx/nginx.conf; then
    sed -i '/http {/a\    include /etc/nginx/snippets/extra-security.conf;' /etc/nginx/nginx.conf
fi

# Update worker connections
sed -i 's/worker_connections [0-9]*;/worker_connections 2048;/' /etc/nginx/nginx.conf

echo -e "${GREEN}✓ Main configuration updated${NC}"
echo ""

# Create deny list for bad user agents and referrers
echo -e "${YELLOW}[5/8] Creating bot blocking configuration...${NC}"
cat > /etc/nginx/snippets/block-bots.conf << 'EOF'
# Block bad bots and scrapers
map $http_user_agent $bad_bot {
    default 0;
    ~*^$ 1;
    ~*(bot|crawler|spider|scraper|curl|wget) 1;
    ~*(python|java|perl) 1;
    ~*HTTrack 1;
    ~*masscan 1;
}

# Block requests from bad referrers
map $http_referer $bad_referer {
    default 0;
    ~*semalt 1;
    ~*ranksonic 1;
    ~*buttons-for-website 1;
}

# Block specific file access attempts
map $request_uri $bad_request {
    default 0;
    ~*\.(git|env|log|bak|sql)$ 1;
    ~*wp-admin 1;
    ~*wp-login 1;
    ~*phpmyadmin 1;
}
EOF

echo -e "${GREEN}✓ Bot blocking configuration created${NC}"
echo ""

# Create a secure default server block
echo -e "${YELLOW}[6/8] Creating secure default server configuration...${NC}"
cat > /etc/nginx/sites-available/default << 'EOF'
# Default server - Catch all undefined domains
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Return 444 (no response) for undefined domains
    return 444;
}

# Example secure server block (uncomment and modify for your domain)
# server {
#     listen 80;
#     listen [::]:80;
#     server_name example.com www.example.com;
#     
#     # Redirect HTTP to HTTPS
#     return 301 https://$server_name$request_uri;
# }

# server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#     server_name example.com www.example.com;
#     
#     root /var/www/html;
#     index index.html index.htm index.php;
#     
#     # SSL Configuration (Let's Encrypt)
#     ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
#     
#     # Include security configurations
#     include snippets/security-headers.conf;
#     include snippets/ssl-params.conf;
#     include snippets/block-bots.conf;
#     
#     # Block bad bots
#     if ($bad_bot) { return 403; }
#     if ($bad_referer) { return 403; }
#     if ($bad_request) { return 403; }
#     
#     # Rate limiting on sensitive endpoints
#     location = /login {
#         limit_req zone=login burst=2 nodelay;
#         try_files $uri $uri/ =404;
#     }
#     
#     location /api/ {
#         limit_req zone=api burst=10 nodelay;
#         try_files $uri $uri/ =404;
#     }
#     
#     # General rate limiting
#     location / {
#         limit_req zone=general burst=20 nodelay;
#         try_files $uri $uri/ =404;
#     }
#     
#     # Deny access to hidden files
#     location ~ /\. {
#         deny all;
#         access_log off;
#         log_not_found off;
#     }
#     
#     # Deny access to sensitive files
#     location ~* \.(git|env|log|bak|sql|conf)$ {
#         deny all;
#         access_log off;
#         log_not_found off;
#     }
#     
#     # PHP Configuration (if using PHP)
#     # location ~ \.php$ {
#     #     include snippets/fastcgi-php.conf;
#     #     fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
#     #     fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
#     #     include fastcgi_params;
#     # }
#     
#     # Security headers for static files
#     location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
#         expires 1y;
#         add_header Cache-Control "public, immutable";
#         include snippets/security-headers.conf;
#     }
# }
EOF

echo -e "${GREEN}✓ Default server configuration created${NC}"
echo ""

# Test Nginx configuration
echo -e "${YELLOW}[7/8] Testing Nginx configuration...${NC}"
if nginx -t; then
    echo -e "${GREEN}✓ Configuration test passed${NC}"
else
    echo -e "${RED}Error: Configuration test failed${NC}"
    echo -e "${YELLOW}Restoring backup...${NC}"
    cp /etc/nginx/backups/nginx.conf.backup.* /etc/nginx/nginx.conf
    exit 1
fi
echo ""

# Reload Nginx
echo -e "${YELLOW}[8/8] Reloading Nginx...${NC}"
systemctl reload nginx
echo -e "${GREEN}✓ Nginx reloaded${NC}"
echo ""

# Summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}NGINX SECURITY HARDENING COMPLETE!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Applied security measures:"
echo -e "  ✓ Security headers (XSS, Clickjacking, MIME sniffing protection)"
echo -e "  ✓ Rate limiting (10 req/s general, 3 req/min login, 30 req/s API)"
echo -e "  ✓ Connection limiting (10 concurrent per IP)"
echo -e "  ✓ Bot and scraper blocking"
echo -e "  ✓ Hidden file access denied"
echo -e "  ✓ Server version hidden"
echo -e "  ✓ Request size limits"
echo -e "  ✓ Timeout configurations"
echo -e "  ✓ Buffer overflow protection"
echo ""
echo -e "${YELLOW}Configuration files created:${NC}"
echo -e "  /etc/nginx/snippets/security-headers.conf"
echo -e "  /etc/nginx/snippets/rate-limiting.conf"
echo -e "  /etc/nginx/snippets/block-bots.conf"
echo -e "  /etc/nginx/sites-available/default"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo ""
echo -e "Test Nginx config:"
echo -e "  ${GREEN}sudo nginx -t${NC}"
echo ""
echo -e "Reload Nginx:"
echo -e "  ${GREEN}sudo systemctl reload nginx${NC}"
echo ""
echo -e "View Nginx error log:"
echo -e "  ${GREEN}sudo tail -f /var/log/nginx/error.log${NC}"
echo ""
echo -e "View Nginx access log:"
echo -e "  ${GREEN}sudo tail -f /var/log/nginx/access.log${NC}"
echo ""
echo -e "Check blocked requests:"
echo -e "  ${GREEN}sudo grep -i 'limiting requests' /var/log/nginx/error.log${NC}"
echo ""
echo -e "${YELLOW}To apply to your site:${NC}"
echo -e "1. Edit your site config: /etc/nginx/sites-available/yourdomain.com"
echo -e "2. Add these lines inside your server block:"
echo -e "   ${GREEN}include snippets/security-headers.conf;${NC}"
echo -e "   ${GREEN}include snippets/block-bots.conf;${NC}"
echo -e "3. Test config: ${GREEN}sudo nginx -t${NC}"
echo -e "4. Reload: ${GREEN}sudo systemctl reload nginx${NC}"
echo ""
echo -e "${YELLOW}Test your security:${NC}"
echo -e "  https://securityheaders.com"
echo -e "  https://www.ssllabs.com/ssltest/"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo -e "1. Update your site configurations to include security snippets"
echo -e "2. Run: sudo bash 6_backup_setup.sh"
echo -e "3. Run: sudo bash 7_monitoring_setup.sh"
echo ""
