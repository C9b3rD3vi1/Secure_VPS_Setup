# VPS Security Setup Checklist

Use this checklist to track your progress through the security setup.

## Pre-Setup

- [ ] Take VPS snapshot/backup
- [ ] Have SSH access
- [ ] Have root/sudo privileges
- [ ] (Optional) Domain name configured
- [ ] Downloaded all scripts
- [ ] Made scripts executable: `chmod +x *.sh`

## Setup Steps

### 1. Initial Server Hardening
- [ ] Run: `sudo bash 1_initial_setup.sh`
- [ ] Created non-root user (if prompted)
- [ ] Tested SSH with new user
- [ ] Verified firewall active: `sudo ufw status`
- [ ] Checked automatic updates: `sudo systemctl status unattended-upgrades`

### 2. SSL/TLS Setup (Optional - Skip if no domain)
- [ ] Run: `sudo bash 2_ssl_setup.sh`
- [ ] Entered domain name
- [ ] Entered email for alerts
- [ ] Verified SSL certificate obtained
- [ ] Tested HTTPS access: `https://yourdomain.com`
- [ ] Verified auto-renewal: `sudo certbot renew --dry-run`

### 3. Fail2ban Setup
- [ ] Run: `sudo bash 3_fail2ban_setup.sh`
- [ ] Checked fail2ban status: `sudo fail2ban-client status`
- [ ] Verified jails active: `sudo fail2ban-client status sshd`
- [ ] Noted whitelisted IPs (if any)

### 4. Advanced Firewall
- [ ] Run: `sudo bash 4_firewall_setup.sh`
- [ ] Added custom ports (if needed)
- [ ] Enabled logging (if desired)
- [ ] Verified rules: `sudo iptables -L -v -n`
- [ ] Tested SSH still works
- [ ] Tested web access still works

### 5. Nginx Security (Skip if not using Nginx)
- [ ] Run: `sudo bash 5_nginx_security.sh`
- [ ] Nginx config test passed: `sudo nginx -t`
- [ ] Website still loads correctly
- [ ] Tested security headers: https://securityheaders.com
- [ ] Tested SSL: https://www.ssllabs.com/ssltest/

### 6. Automated Backups
- [ ] Run: `sudo bash 6_backup_setup.sh`
- [ ] Specified databases to backup
- [ ] Specified web directories
- [ ] Initial backup completed successfully
- [ ] Checked backup exists: `ls -lh /var/backups/server/daily/`
- [ ] Noted backup schedule (daily 2 AM)

### 7. Monitoring Setup
- [ ] Run: `sudo bash 7_monitoring_setup.sh`
- [ ] Entered email for alerts (optional)
- [ ] Viewed status dashboard: `sudo server-status.sh`
- [ ] Checked health monitor log: `sudo tail /var/log/monitoring/health-check.log`
- [ ] Verified cron jobs: `crontab -l`

## Post-Setup Verification

### Immediate Tests
- [ ] SSH access works
- [ ] Website loads (HTTP and HTTPS)
- [ ] Can sudo as non-root user
- [ ] Fail2ban is running: `sudo systemctl status fail2ban`
- [ ] Nginx is running: `sudo systemctl status nginx` (if applicable)
- [ ] Backups directory exists: `ls /var/backups/server/`
- [ ] Firewall is active: `sudo ufw status`

### Security Tests
- [ ] Test failed SSH login (should ban after 3 attempts)
- [ ] Verify SSL certificate: `curl -I https://yourdomain.com`
- [ ] Check security headers: view source or use online tool
- [ ] Run status dashboard: `sudo server-status.sh`
- [ ] Check for vulnerabilities: `sudo fail2ban-client status`

### Documentation
- [ ] Noted SSH port (default: 22)
- [ ] Saved non-root username
- [ ] Noted email for alerts
- [ ] Documented custom open ports
- [ ] Saved domain name (if applicable)
- [ ] Documented backup schedule

## Daily Maintenance (First Week)

- [ ] Day 1: Check monitoring logs
- [ ] Day 2: Verify backups running
- [ ] Day 3: Check fail2ban status
- [ ] Day 4: Review security events
- [ ] Day 5: Check disk space
- [ ] Day 6: Review firewall logs
- [ ] Day 7: Test backup restore

## Weekly Maintenance

- [ ] Run status dashboard: `sudo server-status.sh`
- [ ] Check fail2ban banned IPs
- [ ] Review monitoring logs for alerts
- [ ] Verify backups are running
- [ ] Check disk usage
- [ ] Review security logs

## Monthly Maintenance

- [ ] Update system: `sudo apt update && sudo apt upgrade`
- [ ] Check SSL certificate expiry: `sudo certbot certificates`
- [ ] Review and clean old logs
- [ ] Test backup restore procedure
- [ ] Review and update firewall rules if needed
- [ ] Check for security updates

## Emergency Contacts & Info

**VPS Provider:** ___________________________
**Support URL:** ___________________________
**Console Access:** ___________________________

**Server Details:**
- IP Address: ___________________________
- Hostname: ___________________________
- OS Version: ___________________________
- Non-root user: ___________________________
- SSH Port: ___________________________

**Domain (if applicable):**
- Domain: ___________________________
- SSL Provider: Let's Encrypt
- DNS Provider: ___________________________

**Backup Details:**
- Location: /var/backups/server/
- Daily retention: 7 days
- Weekly retention: 4 weeks
- Time: 2:00 AM

**Monitoring:**
- Health checks: Every 15 minutes
- Security scans: Every 2 hours
- Alert email: ___________________________

## Troubleshooting Quick Reference

**Lost SSH Access:**
1. Use VPS console
2. Check: `sudo systemctl status sshd`
3. Check firewall: `sudo iptables -L`

**Website Down:**
1. Check Nginx: `sudo systemctl status nginx`
2. Check logs: `sudo tail /var/log/nginx/error.log`
3. Test config: `sudo nginx -t`

**Backup Failed:**
1. Check logs: `sudo tail /var/backups/server/logs/backup-*.log`
2. Run manually: `sudo /usr/local/bin/server-backup.sh`
3. Check disk space: `df -h`

**High Resource Usage:**
1. Run dashboard: `sudo server-status.sh`
2. Check processes: `htop`
3. Review logs: `sudo tail /var/log/monitoring/health-check.log`

## Notes

Use this space for any additional notes or customizations:

_______________________________________________
_______________________________________________
_______________________________________________
_______________________________________________
_______________________________________________

## Completion

Setup completed on: ___________________________
Completed by: ___________________________
All tests passed: [ ] Yes [ ] No

**Signature:** ___________________________
