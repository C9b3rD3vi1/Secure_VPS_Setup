# Secure VPS Setup Scripts - Production-Ready Security

Complete security hardening suite for Ubuntu 20.04/22.04 VPS servers. 7 scripts covering everything from initial hardening to automated backups and monitoring.

> Built by **Simux Tech** — battle-tested on production infrastructure.

## 📦 What's Included

### Core Scripts

1. **1_initial_setup.sh** - Server Hardening
   - System updates and security packages
   - SSH hardening (disable root login, configure timeouts)
   - Basic UFW firewall setup
   - User management
   - Automatic security updates

2. **2_ssl_setup.sh** - SSL/TLS with Let's Encrypt
   - Automated SSL certificate installation
   - Auto-renewal configuration
   - SSL security hardening (TLS 1.2+, strong ciphers)
   - HSTS and security headers

3. **3_fail2ban_setup.sh** - Intrusion Prevention
   - SSH brute force protection
   - Nginx/Apache protection
   - WordPress login protection
   - Bad bot blocking
   - Repeat offender tracking

4. **4_firewall_setup.sh** - Advanced Firewall Rules
   - iptables production rules
   - Rate limiting (SSH, HTTP/HTTPS)
   - DDoS protection
   - Attack pattern blocking
   - Persistent rules across reboots

5. **5_nginx_security.sh** - Nginx Hardening
   - Security headers (XSS, Clickjacking, MIME sniffing)
   - Rate limiting per endpoint
   - Bot blocking
   - Request size limits
   - Timeout configurations

6. **6_backup_setup.sh** - Automated Backups
   - Daily and weekly backup rotation
   - Database backups (PostgreSQL/MySQL)
   - Web directory backups
   - Configuration backups
   - Automated cleanup

7. **7_monitoring_setup.sh** - Monitoring & Alerting
   - Health checks (CPU, memory, disk)
   - Security monitoring
   - Service status monitoring
   - Network traffic monitoring
   - Optional email alerts

## 🚀 Quick Start

### Prerequisites

- Ubuntu 20.04 or 22.04 VPS
- Root or sudo access
- SSH access to server
- (Optional) Domain name for SSL setup

### Installation

```bash
# 1. Download the scripts
wget https://your-domain.com/security-scripts.zip
unzip security-scripts.zip
cd security-scripts

# 2. Make all scripts executable
chmod +x *.sh

# 3. Run scripts in order
sudo bash 1_initial_setup.sh
sudo bash 2_ssl_setup.sh          # If you have a domain
sudo bash 3_fail2ban_setup.sh
sudo bash 4_firewall_setup.sh
sudo bash 5_nginx_security.sh     # If using Nginx
sudo bash 6_backup_setup.sh
sudo bash 7_monitoring_setup.sh
```

## 📋 Detailed Setup Guide

### Step 1: Initial Server Hardening

```bash
sudo bash 1_initial_setup.sh
```

**What it does:**
- Updates all system packages
- Installs security tools (fail2ban, ufw, etc.)
- Configures automatic security updates
- Creates non-root user (optional)
- Hardens SSH configuration
- Sets up basic firewall

**Configuration:**
- You'll be prompted to create a new user
- SSH port remains 22 (change manually if needed)
- Root login via SSH is disabled

**⚠️ IMPORTANT:** 
- Test SSH access with new user before logging out
- Keep current session open until verified

### Step 2: SSL/TLS Setup (Optional)

```bash
sudo bash 2_ssl_setup.sh
```

**Requirements:**
- Domain name pointing to your server
- Nginx or Apache installed
- Ports 80 and 443 open

**What it does:**
- Installs Certbot
- Obtains SSL certificate from Let's Encrypt
- Configures auto-renewal
- Applies SSL hardening
- Sets up HTTPS redirect

**You'll need:**
- Domain name (example.com)
- Email address for renewal notifications

### Step 3: Fail2ban Setup

```bash
sudo bash 3_fail2ban_setup.sh
```

**Protection enabled:**
- SSH: 3 failures = 2 hour ban
- Nginx: Multiple protection rules
- WordPress: Login protection
- Repeat offenders: 1 week ban

**Useful commands after setup:**
```bash
# Check status
sudo fail2ban-client status

# View banned IPs
sudo fail2ban-client banned

# Unban an IP
sudo fail2ban-client set sshd unbanip 192.168.1.100
```

### Step 4: Advanced Firewall

```bash
sudo bash 4_firewall_setup.sh
```

**Features:**
- SSH rate limiting (3 connections/minute)
- DDoS protection
- Attack pattern blocking
- Custom port configuration
- Persistent rules

**Default open ports:**
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)

### Step 5: Nginx Security (Optional)

```bash
sudo bash 5_nginx_security.sh
```

**Security measures:**
- Security headers
- Rate limiting
- Bot blocking
- Request size limits
- Timeout configurations

**Test your security after setup:**
- https://securityheaders.com
- https://www.ssllabs.com/ssltest/

### Step 6: Automated Backups

```bash
sudo bash 6_backup_setup.sh
```

**Configuration:**
- Choose databases to backup
- Specify web directories
- Set retention periods

**What gets backed up:**
- Databases (PostgreSQL/MySQL)
- Web directories
- System configurations
- Crontabs

**Backup schedule:**
- Daily: 2 AM (keeps 7 days)
- Weekly: Sunday 2 AM (keeps 4 weeks)

**Restore a backup:**
```bash
# View available backups
sudo /usr/local/bin/server-restore.sh

# Extract files
cd /var/backups/server/daily/backup-YYYYMMDD-HHMMSS/
sudo tar -xzf directory-name.tar.gz -C /restore/location/

# Restore database
sudo -u postgres psql dbname < databases/dbname-postgres.sql.gz
```

### Step 7: Monitoring Setup

```bash
sudo bash 7_monitoring_setup.sh
```

**Monitors:**
- CPU usage (threshold: 80%)
- Memory usage (threshold: 85%)
- Disk usage (threshold: 85%)
- Service status
- Failed login attempts
- New users
- Suspicious processes

**View status dashboard:**
```bash
sudo server-status.sh
```

## 🔧 Configuration Files

### Important Locations

```
/etc/nginx/
├── nginx.conf                    # Main Nginx config
├── snippets/
│   ├── security-headers.conf     # Security headers
│   ├── rate-limiting.conf        # Rate limits
│   ├── ssl-params.conf           # SSL configuration
│   └── block-bots.conf           # Bot blocking

/etc/fail2ban/
├── jail.local                    # Fail2ban configuration
└── filter.d/                     # Custom filters

/etc/iptables/
├── rules.v4                      # IPv4 firewall rules
└── rules.v6                      # IPv6 firewall rules

/var/backups/server/
├── daily/                        # Daily backups
├── weekly/                       # Weekly backups
└── logs/                         # Backup logs

/var/log/monitoring/
├── health-check.log              # Health check logs
└── security-monitor.log          # Security logs
```

## 📊 Monitoring & Maintenance

### Daily Checks

```bash
# View server status
sudo server-status.sh

# Check fail2ban status
sudo fail2ban-client status

# View recent security events
sudo tail -50 /var/log/monitoring/security-monitor.log

# Check backup status
ls -lh /var/backups/server/daily/
```

### Weekly Checks

```bash
# Review monitoring logs
sudo cat /var/log/monitoring/health-check.log | grep ALERT

# Check disk usage
df -h

# Review system logs
sudo journalctl -p 3 -xb  # Priority 3 = errors

# Verify backups
sudo /usr/local/bin/server-restore.sh
```

### Monthly Checks

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Check SSL certificate expiry
sudo certbot certificates

# Review firewall rules
sudo iptables -L -v -n --line-numbers

# Test backup restore (on test server)
```

## 🛠️ Customization

### Add Custom Ports to Firewall

```bash
# Edit firewall script or add manually
sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
sudo netfilter-persistent save
```

### Whitelist IP Address

```bash
# In fail2ban
sudo fail2ban-client set sshd unbanip 192.168.1.100

# In firewall (permanent whitelist)
sudo iptables -I INPUT -s 192.168.1.100 -j ACCEPT
sudo netfilter-persistent save
```

### Adjust Rate Limits

Edit `/etc/nginx/snippets/rate-limiting.conf`:
```nginx
# Change from 10r/s to 20r/s
limit_req_zone $binary_remote_addr zone=general:10m rate=20r/s;
```

Then reload Nginx:
```bash
sudo systemctl reload nginx
```

### Change Backup Retention

Edit `/usr/local/bin/server-backup.sh`:
```bash
RETENTION_DAYS=14      # Keep daily for 14 days
RETENTION_WEEKS=8      # Keep weekly for 8 weeks
```

## 🚨 Troubleshooting

### Lost SSH Access

1. Use VPS provider's console
2. Check firewall: `sudo iptables -L`
3. Check SSH: `sudo systemctl status sshd`
4. Restore backup config if needed

### Fail2ban Blocking Legitimate IPs

```bash
# Unban IP
sudo fail2ban-client set sshd unbanip YOUR_IP

# Whitelist permanently
# Edit /etc/fail2ban/jail.local
ignoreip = 127.0.0.1/8 ::1 YOUR_IP
```

### Nginx Won't Start After Security Config

```bash
# Test configuration
sudo nginx -t

# Restore backup
sudo cp /etc/nginx/backups/nginx.conf.backup.* /etc/nginx/nginx.conf

# Restart
sudo systemctl restart nginx
```

### Backup Script Failing

```bash
# Check logs
sudo tail -100 /var/backups/server/logs/backup-*.log

# Run manually to see errors
sudo /usr/local/bin/server-backup.sh

# Check disk space
df -h
```

## ⚠️ Important Security Notes

1. **Test in staging first** - Always test these scripts on a non-production server first

2. **Keep SSH access** - Never lock yourself out. Always keep one SSH session open when making changes

3. **Backup before applying** - Take a snapshot of your VPS before running security scripts

4. **Monitor logs** - Check logs daily for the first week after setup

5. **Update regularly** - Keep scripts and system packages up to date

6. **Off-site backups** - Consider storing backups on a different server or cloud storage

7. **Test restore process** - Regularly test that you can restore from backups

8. **Strong passwords** - Use strong passwords for all user accounts and databases

9. **SSH keys** - Use SSH key authentication instead of passwords when possible

10. **Security is ongoing** - Security is not a one-time setup. Regular monitoring and updates are essential

## 📧 Support

For issues or questions:
- Email: support@simuxtech.com
- WhatsApp: +254 740 458 874
- Website: https://simuxtech.com

## 📄 License

These scripts are provided as-is for educational and production use.

## 🏆 Credits

Developed by Simux Tech
- Fortinet-certified security engineer
- 3+ years production experience
- 99.7% uptime track record

---

**Remember:** Security is a journey, not a destination. Keep learning, keep monitoring, keep improving.
