#!/bin/bash

###############################################################################
# FAIL2BAN INTRUSION PREVENTION SETUP
# Purpose: Configure fail2ban to prevent brute force attacks
# Usage: sudo bash 3_fail2ban_setup.sh
# Author: Simux Tech
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}FAIL2BAN SETUP${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Install fail2ban if not already installed
echo -e "${YELLOW}[1/5] Installing fail2ban...${NC}"
apt-get update -qq
apt-get install -y fail2ban
echo -e "${GREEN}✓ fail2ban installed${NC}"
echo ""

# Create local configuration file
echo -e "${YELLOW}[2/5] Creating fail2ban configuration...${NC}"

# Backup existing config if present
if [ -f /etc/fail2ban/jail.local ]; then
    cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup
    echo "Existing config backed up to jail.local.backup"
fi

# Create jail.local with production settings
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban duration (in seconds): 1 hour
bantime = 3600

# Find time window (in seconds): 10 minutes
findtime = 600

# Maximum number of failures before ban
maxretry = 5

# Destination email for alerts (optional)
destemail = root@localhost
sender = fail2ban@localhost

# Action to take: ban only (change to "%(action_mwl)s" to send email alerts)
action = %(action_)s

# Ignore localhost
ignoreip = 127.0.0.1/8 ::1

# ============================================
# SSH PROTECTION
# ============================================
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
findtime = 600

# ============================================
# NGINX PROTECTION
# ============================================
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
port = http,https
filter = nginx-noproxy
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
findtime = 60
bantime = 600

# ============================================
# APACHE PROTECTION (uncomment if using Apache)
# ============================================
# [apache-auth]
# enabled = true
# port = http,https
# filter = apache-auth
# logpath = /var/log/apache*/*error.log
# maxretry = 3

# [apache-badbots]
# enabled = true
# port = http,https
# filter = apache-badbots
# logpath = /var/log/apache*/*access.log
# maxretry = 2

# [apache-noscript]
# enabled = true
# port = http,https
# filter = apache-noscript
# logpath = /var/log/apache*/*error.log
# maxretry = 6

# [apache-overflows]
# enabled = true
# port = http,https
# filter = apache-overflows
# logpath = /var/log/apache*/*error.log
# maxretry = 2

# ============================================
# PHP/WORDPRESS PROTECTION
# ============================================
[php-url-fopen]
enabled = true
port = http,https
filter = php-url-fopen
logpath = /var/log/nginx/access.log

# ============================================
# RECIDIVE - Ban repeat offenders for longer
# ============================================
[recidive]
enabled = true
filter = recidive
logpath = /var/log/fail2ban.log
action = %(action_mwl)s
bantime = 604800  ; 1 week
findtime = 86400  ; 1 day
maxretry = 3
EOF

echo -e "${GREEN}✓ Configuration created${NC}"
echo ""

# Create custom filters
echo -e "${YELLOW}[3/5] Creating custom filters...${NC}"

# WordPress login protection filter
cat > /etc/fail2ban/filter.d/wordpress-auth.conf << 'EOF'
[Definition]
failregex = ^<HOST> .* "POST .*/wp-login.php
            ^<HOST> .* "POST .*/xmlrpc.php
ignoreregex =
EOF

# Add WordPress jail if it doesn't exist
if ! grep -q "\[wordpress-auth\]" /etc/fail2ban/jail.local; then
    cat >> /etc/fail2ban/jail.local << 'EOF'

# ============================================
# WORDPRESS PROTECTION
# ============================================
[wordpress-auth]
enabled = true
filter = wordpress-auth
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
fi

echo -e "${GREEN}✓ Custom filters created${NC}"
echo ""

# Enable and start fail2ban
echo -e "${YELLOW}[4/5] Starting fail2ban service...${NC}"
systemctl enable fail2ban
systemctl restart fail2ban
sleep 2  # Give it time to start

if systemctl is-active --quiet fail2ban; then
    echo -e "${GREEN}✓ fail2ban is running${NC}"
else
    echo -e "${RED}Error: fail2ban failed to start${NC}"
    exit 1
fi
echo ""

# Test configuration
echo -e "${YELLOW}[5/5] Testing configuration...${NC}"
fail2ban-client status

echo ""
echo -e "${GREEN}✓ Configuration test passed${NC}"
echo ""

# Summary and useful commands
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}FAIL2BAN SETUP COMPLETE!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Active protections:"
echo -e "  ✓ SSH (3 failures = 2 hour ban)"
echo -e "  ✓ Nginx authentication"
echo -e "  ✓ Bad bots blocking"
echo -e "  ✓ Script injection attempts"
echo -e "  ✓ Proxy attempts"
echo -e "  ✓ WordPress login protection"
echo -e "  ✓ Repeat offender tracking (1 week ban)"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo ""
echo -e "Check status of all jails:"
echo -e "  ${GREEN}sudo fail2ban-client status${NC}"
echo ""
echo -e "Check specific jail (e.g., sshd):"
echo -e "  ${GREEN}sudo fail2ban-client status sshd${NC}"
echo ""
echo -e "Unban an IP address:"
echo -e "  ${GREEN}sudo fail2ban-client set sshd unbanip 192.168.1.100${NC}"
echo ""
echo -e "View banned IPs:"
echo -e "  ${GREEN}sudo fail2ban-client banned${NC}"
echo ""
echo -e "View fail2ban log:"
echo -e "  ${GREEN}sudo tail -f /var/log/fail2ban.log${NC}"
echo ""
echo -e "View current bans:"
echo -e "  ${GREEN}sudo iptables -L -n | grep DROP${NC}"
echo ""
echo -e "${YELLOW}Configuration files:${NC}"
echo -e "  Main config: /etc/fail2ban/jail.local"
echo -e "  Filters: /etc/fail2ban/filter.d/"
echo -e "  Logs: /var/log/fail2ban.log"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo -e "1. Monitor logs for the first few days"
echo -e "2. Whitelist trusted IPs if needed (add to ignoreip in jail.local)"
echo -e "3. Run: sudo bash 4_firewall_setup.sh"
echo -e "4. Run: sudo bash 6_backup_setup.sh"
echo ""
echo -e "${GREEN}Protection is now active!${NC}"
echo ""
