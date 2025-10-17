# TURN Server Deployment Guide

## 🚀 Quick Deployment

### Prerequisites
- Ubuntu 20.04+ or CentOS 8+
- Root access
- Public IP address
- Ports 3478 and 5349 available

### One-Command Setup
```bash
# Clone and setup
git clone <repo-url>
cd coturn-server
sudo ./scripts/setup.sh
```

## 🏗️ Manual Deployment

### 1. Install coturn
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install coturn

# CentOS/RHEL
sudo yum install coturn
```

### 2. Configure
```bash
# Copy configuration
sudo cp coturn.conf /etc/coturn/coturn.conf

# Edit settings
sudo nano /etc/coturn/coturn.conf

# Set external IP
external-ip=YOUR_PUBLIC_IP/PRIVATE_IP

# Change secret key
static-auth-secret=your-secure-secret-key
```

### 3. Start Service
```bash
# Enable and start
sudo systemctl enable coturn
sudo systemctl start coturn

# Check status
sudo systemctl status coturn
```

## 🔧 Production Configuration

### SSL/TLS Setup
```bash
# Generate certificates
sudo mkdir -p /etc/ssl/coturn
sudo openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/coturn/key.pem -out /etc/ssl/coturn/cert.pem -days 365 -nodes

# Update configuration
echo "cert=/etc/ssl/coturn/cert.pem" | sudo tee -a /etc/coturn/coturn.conf
echo "pkey=/etc/ssl/coturn/key.pem" | sudo tee -a /etc/coturn/coturn.conf
```

### Firewall Configuration
```bash
# UFW
sudo ufw allow 3478/udp
sudo ufw allow 3478/tcp
sudo ufw allow 5349/tcp

# firewalld
sudo firewall-cmd --permanent --add-port=3478/udp
sudo firewall-cmd --permanent --add-port=3478/tcp
sudo firewall-cmd --permanent --add-port=5349/tcp
sudo firewall-cmd --reload
```

## 📊 Monitoring

### Health Checks
```bash
# Service status
sudo systemctl status coturn

# Port listening
netstat -tulnp | grep 3478

# Test connectivity
nc -u your-server.com 3478
```

### Log Monitoring
```bash
# Real-time logs
sudo tail -f /var/log/coturn/coturn.log

# Error monitoring
sudo grep -i error /var/log/coturn/coturn.log
```

## 🔒 Security

### Production Checklist
- [ ] Set strong authentication secret
- [ ] Configure external IP correctly
- [ ] Enable SSL/TLS certificates
- [ ] Restrict allowed IP ranges
- [ ] Set up firewall rules
- [ ] Monitor logs for abuse
- [ ] Regular security updates

### Access Control
```ini
# Restrict to specific IPs
allowed-peer-ip=203.0.113.0/24
allowed-peer-ip=198.51.100.0/24

# Block private networks
denied-peer-ip=10.0.0.0/8
denied-peer-ip=172.16.0.0/12
denied-peer-ip=192.168.0.0/16
```

## 🚨 Troubleshooting

### Common Issues

1. **Service won't start**
   ```bash
   # Check configuration
   sudo turnserver -c /etc/coturn/coturn.conf --check-config
   
   # Check logs
   sudo journalctl -u coturn -f
   ```

2. **External IP not set**
   ```bash
   # Edit configuration
   sudo nano /etc/coturn/coturn.conf
   
   # Set external-ip
   external-ip=YOUR_PUBLIC_IP/PRIVATE_IP
   ```

3. **Port not accessible**
   ```bash
   # Check firewall
   sudo ufw status
   
   # Check if port is listening
   sudo netstat -tulnp | grep 3478
   ```

## 📈 Performance Tuning

### Bandwidth Optimization
```ini
# Adjust based on usage
total-quota=2000
user-quota=100

# Optimize port range
min-port=40000
max-port=50000
```

### Resource Monitoring
```bash
# Monitor connections
ss -tulnp | grep 3478

# Monitor bandwidth
iftop -i eth0

# Check resource usage
htop
```
