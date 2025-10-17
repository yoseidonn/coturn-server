# CrewDEV TURN Server

A simple TURN server for WebRTC NAT traversal in the CrewDEV project. This server provides packet forwarding without any media processing, making it perfect for P2P connections that need to traverse NAT/firewall restrictions.

## 🎯 Purpose

- **Simple packet forwarding** for WebRTC connections
- **NAT traversal** when direct P2P fails
- **No media processing** - just relay packets
- **Low resource usage** compared to SFU servers

## 🏗️ Architecture

```
Client A ←→ TURN Server ←→ Client B
```

- **Input**: WebRTC packets from Client A
- **Process**: Forward packets unchanged
- **Output**: Same packets to Client B
- **No processing**: No decoding, encoding, or analysis

## 🚀 Quick Start

### Prerequisites
- Ubuntu 20.04+ or CentOS 8+
- Root access for installation
- Public IP address configured

### Installation
```bash
# Clone the repository
git clone <repo-url>
cd coturn-server

# Run setup script
sudo ./scripts/setup.sh
```

### Configuration
```bash
# Edit configuration
sudo nano config/coturn.conf

# Set your public IP
external-ip=YOUR_PUBLIC_IP/PRIVATE_IP

# Change secret key
static-auth-secret=your-secure-secret-key
```

### Start Service
```bash
# Start coturn
sudo systemctl start coturn
sudo systemctl enable coturn

# Check status
sudo systemctl status coturn
```

## 📁 Directory Structure

```
coturn-server/
├── README.md                   # This file
├── coturn.conf                # Main configuration
├── config/                     # Configuration files
│   ├── coturn.conf            # Production config
│   ├── coturn-dev.conf        # Development config
│   └── ssl/                   # SSL certificates
├── scripts/                    # Setup and management scripts
│   ├── setup.sh               # Main setup script
│   ├── install.sh             # Installation script
│   ├── configure.sh           # Configuration script
│   └── health-check.sh        # Health monitoring
├── docs/                      # Documentation
│   ├── API.md                 # API reference
│   ├── DEPLOYMENT.md          # Deployment guide
│   └── TROUBLESHOOTING.md     # Troubleshooting
└── logs/                      # Log files
    └── coturn.log             # Server logs
```

## ⚙️ Configuration

### Basic Settings
```ini
# Server ports
listening-port=3478
tls-listening-port=5349

# External IP (REQUIRED)
external-ip=203.0.113.1/192.168.1.100

# Authentication
static-auth-secret=your-secret-key
```

### Security Settings
```ini
# Disable old TLS versions
no-tlsv1
no-tlsv1_1

# Restrict access
denied-peer-ip=127.0.0.1-127.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
```

### Performance Settings
```ini
# Bandwidth limits
total-quota=1000
user-quota=50

# Port range
min-port=49152
max-port=65535
```

## 🔧 Usage

### Client Configuration
```javascript
const peerConnection = new RTCPeerConnection({
    iceServers: [
        {
            urls: 'turn:your-turn-server.com:3478',
            username: 'crewdev',
            credential: 'your-secret-key'
        }
    ]
});
```

### FastAPI Integration
```python
@app.get("/media/turn-credentials")
async def get_turn_credentials():
    return {
        "iceServers": [
            {
                "urls": "stun:stun.l.google.com:19302"
            },
            {
                "urls": f"turn:{TURN_HOST}:3478",
                "username": "crewdev",
                "credential": TURN_SECRET
            }
        ]
    }
```

## 📊 Monitoring

### Health Check
```bash
# Check service status
sudo systemctl status coturn

# Check logs
sudo tail -f /var/log/coturn/coturn.log

# Test TURN server
./scripts/health-check.sh
```

### Performance Monitoring
```bash
# Monitor connections
netstat -tulnp | grep 3478

# Monitor bandwidth
iftop -i eth0

# Check resource usage
htop
```

## 🔒 Security

### Production Checklist
- [ ] Set strong `static-auth-secret`
- [ ] Configure `external-ip` correctly
- [ ] Enable SSL certificates
- [ ] Restrict `allowed-peer-ip` ranges
- [ ] Set up firewall rules
- [ ] Monitor logs for abuse

### SSL/TLS Setup
```bash
# Generate certificates
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365

# Update configuration
cert=/etc/ssl/certs/coturn.crt
pkey=/etc/ssl/private/coturn.key
```

## 🚨 Troubleshooting

### Common Issues

1. **TURN server not responding**
   ```bash
   # Check if service is running
   sudo systemctl status coturn
   
   # Check configuration
   sudo coturn -c /etc/coturn/coturn.conf --check-config
   ```

2. **External IP not set**
   ```bash
   # Edit configuration
   sudo nano /etc/coturn/coturn.conf
   
   # Set external-ip
   external-ip=YOUR_PUBLIC_IP/PRIVATE_IP
   ```

3. **Authentication failed**
   ```bash
   # Check secret key
   grep static-auth-secret /etc/coturn/coturn.conf
   
   # Verify client credentials match
   ```

### Debug Mode
```bash
# Run with verbose logging
sudo coturn -c /etc/coturn/coturn.conf -v

# Check specific configuration
sudo coturn -c /etc/coturn/coturn.conf --check-config
```

## 📈 Performance Tuning

### Bandwidth Optimization
```ini
# Adjust quotas based on usage
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
```

## 🔄 Integration with CrewDEV

### Backend Integration
1. **Environment Variables**: Set TURN server details
2. **API Endpoint**: Provide TURN credentials to clients
3. **Health Monitoring**: Check TURN server status

### Client Integration
1. **ICE Servers**: Include TURN server in ICE configuration
2. **Fallback Logic**: Use TURN when P2P fails
3. **Error Handling**: Graceful fallback to SFU if TURN fails

## 📚 Documentation

- [API Reference](docs/API.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

For issues and questions:
1. Check the troubleshooting guide
2. Review the logs
3. Create an issue on GitHub
4. Contact the development team

---

**CrewDEV TURN Server** - Simple, efficient WebRTC NAT traversal 🚀
