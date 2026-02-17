#!/bin/bash

###############################################################################
# MONITORING AND ALERTING SETUP SCRIPT
# Purpose: Set up basic monitoring for server health and security
# Usage: sudo bash 7_monitoring_setup.sh
# Author: Simux Tech
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}MONITORING & ALERTING SETUP${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Get email for alerts (optional)
echo -e "${YELLOW}Email Configuration (Optional):${NC}"
read -p "Enter email for alerts (or press Enter to skip): " ALERT_EMAIL

# Install monitoring tools
echo -e "${YELLOW}[1/6] Installing monitoring tools...${NC}"
apt-get update -qq
apt-get install -y sysstat vnstat htop iotop nethogs mailutils
echo -e "${GREEN}✓ Monitoring tools installed${NC}"
echo ""

# Enable sysstat
sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
systemctl enable sysstat
systemctl restart sysstat

# Set up vnstat for network monitoring
echo -e "${YELLOW}[2/6] Setting up network monitoring...${NC}"
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
vnstat -i $MAIN_INTERFACE
systemctl enable vnstat
systemctl start vnstat
echo -e "${GREEN}✓ Network monitoring configured${NC}"
echo ""

# Create monitoring directory
echo -e "${YELLOW}[3/6] Creating monitoring directory...${NC}"
mkdir -p /var/log/monitoring
chmod 755 /var/log/monitoring
echo -e "${GREEN}✓ Monitoring directory created${NC}"
echo ""

# Create server health check script
echo -e "${YELLOW}[4/6] Creating health check script...${NC}"
cat > /usr/local/bin/server-health-check.sh << 'HEALTH_CHECK_EOF'
#!/bin/bash

###############################################################################
# SERVER HEALTH CHECK SCRIPT
# Monitors CPU, Memory, Disk, and critical services
###############################################################################

# Configuration
LOG_FILE="/var/log/monitoring/health-check.log"
ALERT_EMAIL="ALERT_EMAIL_PLACEHOLDER"
HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=85

# Function to send alert
send_alert() {
    local subject="$1"
    local message="$2"
    
    echo "[$DATE] ALERT: $subject" >> $LOG_FILE
    echo "$message" >> $LOG_FILE
    
    # Send email if configured
    if [ -n "$ALERT_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "[$HOSTNAME] $subject" $ALERT_EMAIL
    fi
}

# Check CPU usage
check_cpu() {
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1)
    
    if [ "$CPU_USAGE" -gt "$CPU_THRESHOLD" ]; then
        send_alert "High CPU Usage" "CPU usage is at ${CPU_USAGE}% (threshold: ${CPU_THRESHOLD}%)"
    fi
}

# Check memory usage
check_memory() {
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
    
    if [ "$MEMORY_USAGE" -gt "$MEMORY_THRESHOLD" ]; then
        send_alert "High Memory Usage" "Memory usage is at ${MEMORY_USAGE}% (threshold: ${MEMORY_THRESHOLD}%)"
    fi
}

# Check disk usage
check_disk() {
    DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    
    if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
        send_alert "High Disk Usage" "Disk usage is at ${DISK_USAGE}% (threshold: ${DISK_THRESHOLD}%)"
    fi
}

# Check critical services
check_services() {
    SERVICES=("nginx" "sshd" "fail2ban")
    
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet $service; then
            continue
        else
            if systemctl list-unit-files | grep -q "^$service"; then
                send_alert "Service Down" "$service is not running!"
            fi
        fi
    done
}

# Check system load
check_load() {
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | cut -d',' -f1)
    CPU_CORES=$(nproc)
    LOAD_THRESHOLD=$(echo "$CPU_CORES * 2" | bc)
    
    if (( $(echo "$LOAD_AVG > $LOAD_THRESHOLD" | bc -l) )); then
        send_alert "High System Load" "Load average is $LOAD_AVG (cores: $CPU_CORES)"
    fi
}

# Run checks
check_cpu
check_memory
check_disk
check_services
check_load

# Log successful check
echo "[$DATE] Health check completed" >> $LOG_FILE

exit 0
HEALTH_CHECK_EOF

# Replace email placeholder
sed -i "s/ALERT_EMAIL_PLACEHOLDER/$ALERT_EMAIL/g" /usr/local/bin/server-health-check.sh

chmod +x /usr/local/bin/server-health-check.sh
echo -e "${GREEN}✓ Health check script created${NC}"
echo ""

# Create security monitoring script
echo -e "${YELLOW}[5/6] Creating security monitoring script...${NC}"
cat > /usr/local/bin/security-monitor.sh << 'SECURITY_MONITOR_EOF'
#!/bin/bash

###############################################################################
# SECURITY MONITORING SCRIPT
# Monitors for security events and suspicious activity
###############################################################################

LOG_FILE="/var/log/monitoring/security-monitor.log"
ALERT_EMAIL="ALERT_EMAIL_PLACEHOLDER"
HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Function to send alert
send_alert() {
    local subject="$1"
    local message="$2"
    
    echo "[$DATE] SECURITY ALERT: $subject" >> $LOG_FILE
    echo "$message" >> $LOG_FILE
    
    if [ -n "$ALERT_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "[$HOSTNAME] SECURITY: $subject" $ALERT_EMAIL
    fi
}

# Check for failed login attempts
check_failed_logins() {
    FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log | wc -l)
    
    if [ "$FAILED_LOGINS" -gt 10 ]; then
        UNIQUE_IPS=$(grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort -u | wc -l)
        send_alert "Multiple Failed Logins" "Failed login attempts: $FAILED_LOGINS from $UNIQUE_IPS unique IPs"
    fi
}

# Check for root login attempts
check_root_logins() {
    ROOT_ATTEMPTS=$(grep "Failed password for root" /var/log/auth.log | wc -l)
    
    if [ "$ROOT_ATTEMPTS" -gt 0 ]; then
        send_alert "Root Login Attempts" "Detected $ROOT_ATTEMPTS failed root login attempts"
    fi
}

# Check for new users
check_new_users() {
    CURRENT_USERS=$(cut -d: -f1 /etc/passwd | sort)
    
    if [ -f /tmp/previous_users.txt ]; then
        NEW_USERS=$(comm -13 /tmp/previous_users.txt <(echo "$CURRENT_USERS"))
        if [ -n "$NEW_USERS" ]; then
            send_alert "New User Detected" "New user(s) added: $NEW_USERS"
        fi
    fi
    
    echo "$CURRENT_USERS" > /tmp/previous_users.txt
}

# Check for suspicious processes
check_suspicious_processes() {
    # Check for common mining processes
    SUSPICIOUS=("minerd" "cgminer" "bfgminer" "xmrig" "cpuminer")
    
    for proc in "${SUSPICIOUS[@]}"; do
        if pgrep -x "$proc" > /dev/null; then
            send_alert "Suspicious Process" "Detected potentially malicious process: $proc"
        fi
    done
}

# Check open ports
check_open_ports() {
    OPEN_PORTS=$(ss -tuln | grep LISTEN | awk '{print $5}' | cut -d':' -f2 | sort -u)
    
    if [ -f /tmp/previous_ports.txt ]; then
        NEW_PORTS=$(comm -13 /tmp/previous_ports.txt <(echo "$OPEN_PORTS"))
        if [ -n "$NEW_PORTS" ]; then
            send_alert "New Open Port" "New listening port(s) detected: $NEW_PORTS"
        fi
    fi
    
    echo "$OPEN_PORTS" > /tmp/previous_ports.txt
}

# Check for suspicious network connections
check_connections() {
    # Check for connections to known malicious IPs (basic example)
    CONNECTIONS=$(ss -tn | grep ESTAB | awk '{print $4}' | cut -d':' -f1 | sort -u)
    
    # You can add blacklist checking here
    # For now, just count total connections
    CONN_COUNT=$(echo "$CONNECTIONS" | wc -l)
    
    if [ "$CONN_COUNT" -gt 100 ]; then
        send_alert "High Connection Count" "Detected $CONN_COUNT established connections"
    fi
}

# Run security checks
check_failed_logins
check_root_logins
check_new_users
check_suspicious_processes
check_open_ports
check_connections

# Log successful check
echo "[$DATE] Security monitor completed" >> $LOG_FILE

exit 0
SECURITY_MONITOR_EOF

# Replace email placeholder
sed -i "s/ALERT_EMAIL_PLACEHOLDER/$ALERT_EMAIL/g" /usr/local/bin/security-monitor.sh

chmod +x /usr/local/bin/security-monitor.sh
echo -e "${GREEN}✓ Security monitoring script created${NC}"
echo ""

# Set up cron jobs
echo -e "${YELLOW}[6/6] Setting up monitoring cron jobs...${NC}"

# Remove old monitoring cron jobs if they exist
crontab -l 2>/dev/null | grep -v "server-health-check.sh\|security-monitor.sh" | crontab - 2>/dev/null || true

# Add new cron jobs
(crontab -l 2>/dev/null; echo "*/15 * * * * /usr/local/bin/server-health-check.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 */2 * * * /usr/local/bin/security-monitor.sh") | crontab -

echo -e "${GREEN}✓ Cron jobs configured${NC}"
echo -e "  - Health checks: Every 15 minutes"
echo -e "  - Security monitoring: Every 2 hours"
echo ""

# Create monitoring dashboard script
cat > /usr/local/bin/server-status.sh << 'STATUS_DASHBOARD_EOF'
#!/bin/bash

###############################################################################
# SERVER STATUS DASHBOARD
# Quick overview of server health
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}SERVER STATUS DASHBOARD${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# System Info
echo -e "${YELLOW}System Information:${NC}"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# CPU Usage
echo -e "${YELLOW}CPU Usage:${NC}"
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "CPU: " 100 - $1"%"}'
echo ""

# Memory Usage
echo -e "${YELLOW}Memory Usage:${NC}"
free -h | grep Mem | awk '{printf "Used: %s / %s (%.0f%%)\n", $3, $2, $3/$2 * 100}'
echo ""

# Disk Usage
echo -e "${YELLOW}Disk Usage:${NC}"
df -h / | tail -1 | awk '{print "Root: " $3 " / " $2 " (" $5 ")"}'
echo ""

# Network Stats
echo -e "${YELLOW}Network Statistics:${NC}"
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
vnstat -i $MAIN_INTERFACE --oneline | awk -F';' '{print "Today: RX " $4 " / TX " $5}'
echo ""

# Active Services
echo -e "${YELLOW}Critical Services:${NC}"
services=("nginx" "sshd" "fail2ban")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo -e "  ${GREEN}✓${NC} $service is running"
    else
        if systemctl list-unit-files | grep -q "^$service"; then
            echo -e "  ${RED}✗${NC} $service is NOT running"
        fi
    fi
done
echo ""

# Fail2ban Status
echo -e "${YELLOW}Fail2ban Status:${NC}"
if command -v fail2ban-client &> /dev/null; then
    BANNED_IPS=$(fail2ban-client banned 2>/dev/null | wc -l)
    echo "Currently banned IPs: $BANNED_IPS"
fi
echo ""

# Recent Security Events
echo -e "${YELLOW}Recent Security Events (last hour):${NC}"
FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log | grep "$(date '+%b %_d %H')" | wc -l)
echo "Failed login attempts: $FAILED_LOGINS"
echo ""

# Last Backup
echo -e "${YELLOW}Last Backup:${NC}"
if [ -d "/var/backups/server/daily" ]; then
    LAST_BACKUP=$(ls -t /var/backups/server/daily/ 2>/dev/null | head -1)
    if [ -n "$LAST_BACKUP" ]; then
        echo "Last backup: $LAST_BACKUP"
    else
        echo "No backups found"
    fi
fi
echo ""

echo -e "${GREEN}================================${NC}"
echo ""
STATUS_DASHBOARD_EOF

chmod +x /usr/local/bin/server-status.sh

# Run initial health check
/usr/local/bin/server-health-check.sh

# Summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}MONITORING SETUP COMPLETE!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Monitoring features:"
echo -e "  ✓ Health checks every 15 minutes"
echo -e "  ✓ Security monitoring every 2 hours"
echo -e "  ✓ Network traffic monitoring (vnstat)"
echo -e "  ✓ System statistics (sysstat)"
if [ -n "$ALERT_EMAIL" ]; then
    echo -e "  ✓ Email alerts to: $ALERT_EMAIL"
fi
echo ""
echo -e "What's being monitored:"
echo -e "  • CPU usage (threshold: 80%)"
echo -e "  • Memory usage (threshold: 85%)"
echo -e "  • Disk usage (threshold: 85%)"
echo -e "  • System load"
echo -e "  • Critical services (nginx, sshd, fail2ban)"
echo -e "  • Failed login attempts"
echo -e "  • New users"
echo -e "  • Open ports"
echo -e "  • Suspicious processes"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo ""
echo -e "View server status dashboard:"
echo -e "  ${GREEN}sudo server-status.sh${NC}"
echo ""
echo -e "Run manual health check:"
echo -e "  ${GREEN}sudo /usr/local/bin/server-health-check.sh${NC}"
echo ""
echo -e "Run manual security scan:"
echo -e "  ${GREEN}sudo /usr/local/bin/security-monitor.sh${NC}"
echo ""
echo -e "View monitoring logs:"
echo -e "  ${GREEN}sudo tail -f /var/log/monitoring/health-check.log${NC}"
echo -e "  ${GREEN}sudo tail -f /var/log/monitoring/security-monitor.log${NC}"
echo ""
echo -e "View network stats:"
echo -e "  ${GREEN}vnstat${NC}"
echo -e "  ${GREEN}vnstat -d${NC}  # Daily stats"
echo -e "  ${GREEN}vnstat -m${NC}  # Monthly stats"
echo ""
echo -e "View system stats:"
echo -e "  ${GREEN}sar${NC}       # CPU usage"
echo -e "  ${GREEN}sar -r${NC}    # Memory usage"
echo -e "  ${GREEN}sar -n DEV${NC} # Network usage"
echo ""
echo -e "Monitor processes in real-time:"
echo -e "  ${GREEN}htop${NC}"
echo -e "  ${GREEN}iotop${NC}     # Disk I/O"
echo -e "  ${GREEN}nethogs${NC}   # Network by process"
echo ""
echo -e "${YELLOW}Log locations:${NC}"
echo -e "  Health checks: /var/log/monitoring/health-check.log"
echo -e "  Security: /var/log/monitoring/security-monitor.log"
echo ""
echo -e "${GREEN}All security scripts are now in place!${NC}"
echo ""
