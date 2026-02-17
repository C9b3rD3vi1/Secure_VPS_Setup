#!/bin/bash

###############################################################################
# ADVANCED FIREWALL SETUP WITH IPTABLES
# Purpose: Production-grade firewall rules beyond basic UFW
# Usage: sudo bash 4_firewall_setup.sh
# Author: Simux Tech
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}ADVANCED FIREWALL SETUP${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Install iptables-persistent for rule persistence
echo -e "${YELLOW}[1/6] Installing iptables-persistent...${NC}"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
echo -e "${GREEN}✓ iptables-persistent installed${NC}"
echo ""

# Backup existing rules
echo -e "${YELLOW}[2/6] Backing up existing firewall rules...${NC}"
mkdir -p /etc/iptables/backups
iptables-save > /etc/iptables/backups/rules.v4.backup.$(date +%Y%m%d-%H%M%S)
ip6tables-save > /etc/iptables/backups/rules.v6.backup.$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✓ Existing rules backed up${NC}"
echo ""

# Flush existing rules
echo -e "${YELLOW}[3/6] Clearing existing rules...${NC}"
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
echo -e "${GREEN}✓ Existing rules cleared${NC}"
echo ""

# Set default policies
echo -e "${YELLOW}[4/6] Setting default policies...${NC}"
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
echo -e "${GREEN}✓ Default policies set (DROP incoming, ALLOW outgoing)${NC}"
echo ""

# Apply firewall rules
echo -e "${YELLOW}[5/6] Applying firewall rules...${NC}"

# ============================================
# ALLOW LOCALHOST
# ============================================
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ============================================
# ALLOW ESTABLISHED AND RELATED CONNECTIONS
# ============================================
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ============================================
# DROP INVALID PACKETS
# ============================================
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# ============================================
# RATE LIMITING PROTECTION
# ============================================
# Limit SSH connections (max 3 per minute per IP)
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP

# ============================================
# ALLOW SSH (Port 22)
# ============================================
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# ============================================
# ALLOW HTTP AND HTTPS
# ============================================
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# ============================================
# ALLOW PING (ICMP) - Limited
# ============================================
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 2 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# ============================================
# PROTECTION AGAINST COMMON ATTACKS
# ============================================

# Block null packets (DoS)
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Block syn-flood attacks
iptables -A INPUT -p tcp ! --syn -m conntrack --ctstate NEW -j DROP

# Block XMAS packets
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Block packets with incoming fragments
iptables -A INPUT -f -j DROP

# Block packets with invalid flags
iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

# ============================================
# ADDITIONAL PORTS (OPTIONAL)
# ============================================
echo -e "${YELLOW}Do you need to open additional ports? (e.g., for custom apps)${NC}"
read -p "Enter port numbers separated by spaces (or press Enter to skip): " CUSTOM_PORTS

if [ -n "$CUSTOM_PORTS" ]; then
    for port in $CUSTOM_PORTS; do
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            iptables -A INPUT -p tcp --dport $port -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
            echo -e "${GREEN}✓ Opened port $port${NC}"
        else
            echo -e "${RED}Invalid port: $port (skipped)${NC}"
        fi
    done
fi

# ============================================
# LOG DROPPED PACKETS (Optional)
# ============================================
echo ""
read -p "Enable logging of dropped packets? (y/n): " ENABLE_LOGGING

if [ "$ENABLE_LOGGING" = "y" ]; then
    # Log dropped packets (limited to prevent log flooding)
    iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables-dropped: " --log-level 7
fi

# ============================================
# REJECT ALL OTHER INCOMING TRAFFIC
# ============================================
iptables -A INPUT -j DROP

echo -e "${GREEN}✓ Firewall rules applied${NC}"
echo ""

# Save rules
echo -e "${YELLOW}[6/6] Saving firewall rules...${NC}"
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

# Make rules persistent
netfilter-persistent save
netfilter-persistent reload

echo -e "${GREEN}✓ Rules saved and will persist after reboot${NC}"
echo ""

# Display current rules
echo -e "${YELLOW}Current firewall rules:${NC}"
echo ""
iptables -L -v -n --line-numbers
echo ""

# Summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}FIREWALL SETUP COMPLETE!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Active protections:"
echo -e "  ✓ SSH rate limiting (max 3 connections/min)"
echo -e "  ✓ HTTP/HTTPS traffic allowed"
echo -e "  ✓ ICMP (ping) rate limited"
echo -e "  ✓ Protection against:"
echo -e "    - Null packets (DoS)"
echo -e "    - SYN flood attacks"
echo -e "    - XMAS packets"
echo -e "    - Fragmented packets"
echo -e "    - Invalid TCP flags"
echo -e "  ✓ All other incoming traffic blocked"
echo ""
if [ -n "$CUSTOM_PORTS" ]; then
    echo -e "Custom ports opened: $CUSTOM_PORTS"
    echo ""
fi
echo -e "${YELLOW}Useful Commands:${NC}"
echo ""
echo -e "View current rules:"
echo -e "  ${GREEN}sudo iptables -L -v -n --line-numbers${NC}"
echo ""
echo -e "View rules for specific chain:"
echo -e "  ${GREEN}sudo iptables -L INPUT -v -n --line-numbers${NC}"
echo ""
echo -e "Delete a specific rule (by line number):"
echo -e "  ${GREEN}sudo iptables -D INPUT 5${NC}"
echo ""
echo -e "Add a rule to allow a specific IP:"
echo -e "  ${GREEN}sudo iptables -I INPUT -s 192.168.1.100 -j ACCEPT${NC}"
echo ""
echo -e "Save rules after manual changes:"
echo -e "  ${GREEN}sudo netfilter-persistent save${NC}"
echo ""
echo -e "View logged dropped packets:"
echo -e "  ${GREEN}sudo tail -f /var/log/kern.log | grep iptables-dropped${NC}"
echo ""
echo -e "Test firewall from another machine:"
echo -e "  ${GREEN}nmap -p 1-1000 your-server-ip${NC}"
echo ""
echo -e "${YELLOW}Configuration files:${NC}"
echo -e "  IPv4 rules: /etc/iptables/rules.v4"
echo -e "  IPv6 rules: /etc/iptables/rules.v6"
echo -e "  Backups: /etc/iptables/backups/"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo -e "1. Test your applications to ensure they work correctly"
echo -e "2. Monitor logs for unusual activity"
echo -e "3. Run: sudo bash 5_nginx_security.sh (if using Nginx)"
echo -e "4. Run: sudo bash 6_backup_setup.sh"
echo ""
echo -e "${RED}⚠ IMPORTANT:${NC}"
echo -e "If you lose SSH access, you'll need console access to your VPS!"
echo -e "Test SSH connection from a new terminal before closing this one."
echo ""
