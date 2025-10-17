# TURN Server Troubleshooting Guide

## 🚨 Common Issues

### 1. Service Won't Start

#### Symptoms
- `systemctl status coturn` shows failed
- Service keeps restarting
- No listening ports

#### Solutions
```bash
# Check configuration
sudo turnserver -c /etc/coturn/coturn.conf --check-config

# Check logs
sudo journalctl -u coturn -f

# Test configuration manually
sudo turnserver -c /etc/coturn/coturn.conf -v
```

#### Common Causes
- Invalid configuration syntax
- Missing external-ip setting
- Permission issues
- Port already in use

### 2. External IP Not Configured

#### Symptoms
- Service starts but clients can't connect
- "External IP not set" in logs
- Connection timeouts

#### Solutions
```bash
# Edit configuration
sudo nano /etc/coturn/coturn.conf

# Add external IP
external-ip=YOUR_PUBLIC_IP/PRIVATE_IP

# Restart service
sudo systemctl restart coturn
```

#### Example
```ini
# Get your public IP
curl ifconfig.me

# Set in configuration
external-ip=203.0.113.1/192.168.1.100
```

### 3. Port Not Accessible

#### Symptoms
- Service running but port not listening
- Firewall blocking connections
- Network connectivity issues

#### Solutions
```bash
# Check if port is listening
sudo netstat -tulnp | grep 3478

# Check firewall
sudo ufw status
sudo firewall-cmd --list-ports

# Open ports
sudo ufw allow 3478/udp
sudo ufw allow 3478/tcp
sudo ufw allow 5349/tcp
```

### 4. Authentication Failed

#### Symptoms
- Clients get 401 Unauthorized
- "Authentication failed" in logs
- ICE gathering fails

#### Solutions
```bash
# Check secret key
grep static-auth-secret /etc/coturn/coturn.conf

# Verify client credentials match
# Client must use same username and secret
```

#### Client Configuration
```javascript
// Ensure credentials match server
const peerConnection = new RTCPeerConnection({
    iceServers: [{
        urls: 'turn:your-server.com:3478',
        username: 'crewdev',  // Must match server config
        credential: 'your-secret-key'  // Must match server config
    }]
});
```

### 5. High Resource Usage

#### Symptoms
- High CPU usage
- High memory usage
- Slow performance
- Connection drops

#### Solutions
```bash
# Check resource usage
htop
ps aux | grep turnserver

# Adjust quotas
sudo nano /etc/coturn/coturn.conf

# Reduce limits
total-quota=500
user-quota=25
```

### 6. SSL/TLS Issues

#### Symptoms
- TLS connections fail
- Certificate errors
- "TLS handshake failed" in logs

#### Solutions
```bash
# Check certificate files
ls -la /etc/ssl/coturn/

# Verify certificate
openssl x509 -in /etc/ssl/coturn/cert.pem -text -noout

# Regenerate if needed
sudo openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/coturn/key.pem -out /etc/ssl/coturn/cert.pem -days 365 -nodes
```

## 🔍 Debugging Commands

### Service Status
```bash
# Check service status
sudo systemctl status coturn

# Check if running
ps aux | grep turnserver

# Check listening ports
sudo netstat -tulnp | grep 3478
```

### Configuration Validation
```bash
# Test configuration
sudo turnserver -c /etc/coturn/coturn.conf --check-config

# Dry run with verbose output
sudo turnserver -c /etc/coturn/coturn.conf -v --no-daemon
```

### Network Testing
```bash
# Test STUN port
nc -u your-server.com 3478

# Test TLS port
nc your-server.com 5349

# Check firewall
sudo ufw status verbose
sudo iptables -L
```

### Log Analysis
```bash
# Real-time logs
sudo tail -f /var/log/coturn/coturn.log

# Search for errors
sudo grep -i error /var/log/coturn/coturn.log

# Search for connections
sudo grep -i "allocate" /var/log/coturn/coturn.log

# Check system logs
sudo journalctl -u coturn -f
```

## 📊 Performance Monitoring

### Resource Monitoring
```bash
# CPU and memory usage
htop

# Network connections
ss -tulnp | grep 3478

# Bandwidth usage
iftop -i eth0

# Disk I/O
iotop
```

### Connection Monitoring
```bash
# Active connections
ss -tulnp | grep 3478 | wc -l

# Connection details
ss -tulnp | grep 3478

# Monitor bandwidth per connection
nethogs
```

## 🔧 Configuration Fixes

### Common Configuration Errors

#### 1. Missing external-ip
```ini
# WRONG
# external-ip=YOUR_PUBLIC_IP/PRIVATE_IP

# CORRECT
external-ip=203.0.113.1/192.168.1.100
```

#### 2. Invalid secret key
```ini
# WRONG
static-auth-secret=simple-password

# CORRECT
static-auth-secret=your-very-long-and-secure-secret-key-here
```

#### 3. Port conflicts
```ini
# Check if ports are available
sudo netstat -tulnp | grep 3478
sudo netstat -tulnp | grep 5349

# Change ports if needed
listening-port=3479
tls-listening-port=5350
```

#### 4. Permission issues
```bash
# Fix ownership
sudo chown coturn:coturn /etc/coturn/coturn.conf
sudo chown coturn:coturn /var/log/coturn/
sudo chmod 644 /etc/coturn/coturn.conf
```

## 🚀 Performance Optimization

### Bandwidth Tuning
```ini
# Adjust based on server capacity
total-quota=2000
user-quota=100

# Optimize port range
min-port=40000
max-port=50000
```

### Connection Limits
```ini
# Limit concurrent connections
total-quota=1000
user-quota=50

# Session timeout
stale-nonce=600
```

### Security Hardening
```ini
# Disable old TLS versions
no-tlsv1
no-tlsv1_1

# Restrict access
denied-peer-ip=127.0.0.1-127.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
```

## 📞 Getting Help

### Log Collection
```bash
# Collect diagnostic information
sudo systemctl status coturn > coturn-status.txt
sudo journalctl -u coturn > coturn-journal.txt
sudo cat /var/log/coturn/coturn.log > coturn-logs.txt
sudo netstat -tulnp > netstat.txt
```

### Support Information
When seeking help, provide:
1. Service status output
2. Configuration file
3. Recent logs
4. Error messages
5. System information (OS, version)
6. Network configuration

### Community Resources
- [coturn GitHub Issues](https://github.com/coturn/coturn/issues)
- [WebRTC Community](https://webrtc.org/getting-started/)
- [TURN Protocol RFC](https://tools.ietf.org/html/rfc5766)
