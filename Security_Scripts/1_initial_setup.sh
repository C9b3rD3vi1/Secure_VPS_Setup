#!/bin/bash

###############################################################################
# INITIAL SERVER HARDENING SCRIPT
# Purpose: Basic security hardening for Ubuntu 20.04/22.04 VPS
# Usage: sudo bash 1_initial_setup.sh
# Author: Simux Tech
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}VPS SECURITY HARDENING SCRIPT${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Get server information
echo -e "${YELLOW}[1/10] Gathering server information...${NC}"
HOSTNAME=$(hostname)
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Hostname: $HOSTNAME"
echo "IP Address: $IP_ADDRESS"
echo ""

# Update system
echo -e "${YELLOW}[2/10] Updating system packages...${NC}"
apt-get update -qq
apt-get upgrade -y -qq
echo -e "${GREEN}✓ System updated${NC}"
echo ""

# Install essential security packages
echo -e "${YELLOW}[3/10] Installing security packages...${NC}"
apt-get install -y -qq \
    ufw \
    fail2ban \
    unattended-upgrades \
    apt-listchanges \
    logwatch \
    curl \
    wget \
    git \
    htop \
    vim \
    net-tools

echo -e "${GREEN}✓ Security packages installed${NC}"
echo ""

# Configure automatic security updates
echo -e "${YELLOW}[4/10] Configuring automatic security updates...${NC}"
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

echo -e "${GREEN}✓ Automatic updates configured${NC}"
echo ""

# Create non-root user
echo -e "${YELLOW}[5/10] Creating non-root user...${NC}"
read -p "Enter username for new user (or press Enter to skip): " NEW_USER

if [ -n "$NEW_USER" ]; then
    if id "$NEW_USER" &>/dev/null; then
        echo -e "${YELLOW}User $NEW_USER already exists${NC}"
    else
        adduser --gecos "" "$NEW_USER"
        usermod -aG sudo "$NEW_USER"
        echo -e "${GREEN}✓ User $NEW_USER created and added to sudo group${NC}"
    fi
else
    echo -e "${YELLOW}Skipping user creation${NC}"
fi
echo ""

# SSH Hardening
echo -e "${YELLOW}[6/10] Hardening SSH configuration...${NC}"

# Backup original SSH config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Apply SSH hardening
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Ask user about password authentication
echo -e "${YELLOW}SSH Password Authentication:${NC}"
echo "  Keeping password auth ON is safer for initial setup."
echo "  After adding your SSH key, you should disable it."
read -p "Disable password authentication now? (only if you have SSH keys set up!) (y/n): " DISABLE_PASS_AUTH
if [ "$DISABLE_PASS_AUTH" = "y" ]; then
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    echo -e "${RED}⚠ Password auth DISABLED. Make sure your SSH key works before closing this session!${NC}"
else
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo -e "${YELLOW}Password auth kept ON. Disable it after setting up SSH keys.${NC}"
fi
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' /etc/ssh/sshd_config
sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 2/' /etc/ssh/sshd_config

# Add SSH hardening if not present
grep -q "Protocol 2" /etc/ssh/sshd_config || echo "Protocol 2" >> /etc/ssh/sshd_config
grep -q "AllowUsers" /etc/ssh/sshd_config || echo "# AllowUsers yourusername" >> /etc/ssh/sshd_config

echo -e "${GREEN}✓ SSH hardened (root login disabled, max auth tries: 3)${NC}"
echo -e "${YELLOW}⚠ IMPORTANT: Make sure you have SSH key authentication set up before disabling password auth!${NC}"
echo ""

# Configure basic firewall (UFW)
echo -e "${YELLOW}[7/10] Configuring basic firewall (UFW)...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Ask about additional ports
read -p "Do you need to open additional ports? (y/n): " OPEN_PORTS
if [ "$OPEN_PORTS" = "y" ]; then
    read -p "Enter port numbers (space-separated, e.g., 3000 8080): " PORTS
    for port in $PORTS; do
        ufw allow $port/tcp
        echo "Opened port $port"
    done
fi

ufw --force enable
echo -e "${GREEN}✓ Firewall configured and enabled${NC}"
echo ""

# Disable unused services
echo -e "${YELLOW}[8/10] Disabling unused services...${NC}"
systemctl disable --now bluetooth.service 2>/dev/null || true
systemctl disable --now cups.service 2>/dev/null || true
echo -e "${GREEN}✓ Unused services disabled${NC}"
echo ""

# Configure system limits
echo -e "${YELLOW}[9/10] Configuring system limits...${NC}"
cat >> /etc/security/limits.conf << 'EOF'

# Security limits configured by setup script
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

echo -e "${GREEN}✓ System limits configured${NC}"
echo ""

# Set up basic logging
echo -e "${YELLOW}[10/10] Configuring logging...${NC}"
mkdir -p /var/log/security
touch /var/log/security/access.log
chmod 640 /var/log/security/access.log

# Configure logrotate for security logs
cat > /etc/logrotate.d/security << 'EOF'
/var/log/security/*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
}
EOF

echo -e "${GREEN}✓ Logging configured${NC}"
echo ""

# Restart SSH to apply changes
echo -e "${YELLOW}Restarting SSH service...${NC}"
systemctl restart sshd
echo -e "${GREEN}✓ SSH restarted${NC}"
echo ""

# Summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}INITIAL SETUP COMPLETE!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Summary of changes:"
echo -e "  ✓ System updated and upgraded"
echo -e "  ✓ Security packages installed"
echo -e "  ✓ Automatic security updates enabled"
echo -e "  ✓ SSH hardened (root login disabled)"
echo -e "  ✓ UFW firewall configured"
echo -e "  ✓ Basic logging set up"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo -e "1. Set up SSH key authentication for your user"
echo -e "2. Run: sudo bash 2_ssl_setup.sh (if you have a domain)"
echo -e "3. Run: sudo bash 3_fail2ban_setup.sh"
echo -e "4. Run: sudo bash 4_firewall_setup.sh (advanced rules)"
echo ""
echo -e "${YELLOW}⚠ IMPORTANT SECURITY NOTES:${NC}"
echo -e "- Root login is now disabled via SSH"
echo -e "- Password authentication is still enabled (disable after setting up SSH keys)"
echo -e "- Current SSH port: 22"
echo -e "- Firewall is active (ports 22, 80, 443 open)"
echo ""
echo -e "${RED}⚠ DO NOT CLOSE THIS SESSION until you verify you can login with your new user!${NC}"
echo ""
