#!/bin/bash
# Coturn TURN Server Setup Script for /opt/coturn-server
# Installs coturn, downloads binary, sets proper permissions, installs systemd service

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories and files
COTURN_DIR="/opt/coturn-server"
LOGS_DIR="$COTURN_DIR/logs"
BINARY="/usr/bin/turnserver"
SERVICE_FILE="/etc/systemd/system/coturn.service"
CONFIG_FILE="$COTURN_DIR/coturn.conf"

echo -e "${BLUE}🚀 Coturn TURN Server Setup Script${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root${NC}"
   exit 1
fi

# Detect OS and install coturn
echo -e "${YELLOW}📦 Installing coturn package...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo -e "${RED}❌ Cannot detect OS version${NC}"
    exit 1
fi

echo -e "${BLUE}Detected OS: $OS $VER${NC}"

if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    apt update
    apt install -y coturn
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Rocky"* ]] || [[ "$OS" == *"AlmaLinux"* ]]; then
    if command -v dnf &> /dev/null; then
        dnf install -y coturn
    else
        yum install -y coturn
    fi
else
    echo -e "${RED}❌ Unsupported OS: $OS${NC}"
    exit 1
fi

# Create coturn user if missing
if ! id coturn &>/dev/null; then
    echo -e "${YELLOW}👤 Creating system user 'coturn'...${NC}"
    useradd --system --no-create-home --shell /bin/false coturn
    echo -e "${GREEN}✅ User created${NC}"
else
    echo -e "${GREEN}✅ User 'coturn' already exists${NC}"
fi

# Create directories
echo -e "${YELLOW}📁 Creating directories...${NC}"
# Remove old installation if exists
if [ -d "$COTURN_DIR" ]; then
    echo -e "${YELLOW}🗑️  Removing old installation at $COTURN_DIR${NC}"
    rm -rf "$COTURN_DIR"
fi
mkdir -p "$LOGS_DIR"
chown -R coturn:coturn "$COTURN_DIR"
chmod 750 "$COTURN_DIR"
chmod 750 "$LOGS_DIR"
echo -e "${GREEN}✅ Directories ready${NC}"

# Check config file
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}📝 Creating example coturn.conf...${NC}"
    cat > "$CONFIG_FILE" <<EOF
# Coturn TURN Server Configuration
# Edit this file with your actual values

# Listening ports
listening-port=3478
tls-listening-port=5349

# External IP (REQUIRED - replace with your public IP)
# external-ip=YOUR_PUBLIC_IP/PRIVATE_IP
external-ip=auto-detect

# Authentication
# Use static auth secret for TURN credentials
static-auth-secret=your-secret-key-here-change-in-production

# Realm
realm=crewdev-turn-server

# Logging
log-file=$LOGS_DIR/coturn.log
verbose

# Security
no-multicast-peers
no-cli
no-tlsv1
no-tlsv1_1

# Performance
total-quota=100
bps-capacity=0
stale-nonce=600

# Database (optional - for user management)
# userdb=/etc/coturn/turndb

# Certificates (for TURNS - optional)
# cert=/etc/coturn/cert.pem
# pkey=/etc/coturn/private.pem

# Deny access to private IP ranges
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.0.0.0-192.0.0.255
denied-peer-ip=192.0.2.0-192.0.2.255
denied-peer-ip=192.88.99.0-192.88.99.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=198.18.0.0-198.19.255.255
denied-peer-ip=198.51.100.0-198.51.100.255
denied-peer-ip=203.0.113.0-203.0.113.255
denied-peer-ip=240.0.0.0-255.255.255.255
EOF
    chown coturn:coturn "$CONFIG_FILE"
    chmod 640 "$CONFIG_FILE"
    echo -e "${GREEN}✅ Example coturn.conf created at $CONFIG_FILE${NC}"
fi

# Test configuration
echo -e "${YELLOW}🧪 Testing configuration...${NC}"
if "$BINARY" --config="$CONFIG_FILE" --check-config; then
    echo -e "${GREEN}✅ Configuration is valid${NC}"
else
    echo -e "${RED}❌ Configuration test failed${NC}"
    echo "Please check your coturn.conf file for errors."
    exit 1
fi

# Create systemd service
echo -e "${YELLOW}📋 Installing systemd service...${NC}"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Coturn TURN Server for CrewDEV
Documentation=https://github.com/coturn/coturn
After=network.target
Wants=network.target

[Service]
Type=simple
User=coturn
Group=coturn
WorkingDirectory=$COTURN_DIR
ExecStart=$BINARY --config=$CONFIG_FILE
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=coturn

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# Configure firewall
echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 3478/udp
    ufw allow 3478/tcp
    ufw allow 5349/tcp
    echo -e "${GREEN}✅ UFW firewall configured${NC}"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=3478/udp
    firewall-cmd --permanent --add-port=3478/tcp
    firewall-cmd --permanent --add-port=5349/tcp
    firewall-cmd --reload
    echo -e "${GREEN}✅ firewalld configured${NC}"
else
    echo -e "${YELLOW}⚠️  No firewall detected, please configure manually${NC}"
fi

# Enable and start service
echo -e "${YELLOW}🚀 Starting coturn service...${NC}"
systemctl daemon-reload
systemctl enable coturn
systemctl start coturn

# Check service status
echo -e "${YELLOW}📊 Checking service status...${NC}"
sleep 2
if systemctl is-active --quiet coturn; then
    echo -e "${GREEN}✅ Coturn is running successfully!${NC}"
else
    echo -e "${RED}❌ Coturn failed to start${NC}"
    echo "Check logs: sudo journalctl -u coturn -f"
    exit 1
fi

echo -e "${BLUE}🎉 Setup complete!${NC}"
echo "Logs: $LOGS_DIR"
echo "Config: $CONFIG_FILE"
echo "Binary: $BINARY"
echo "Service: $SERVICE_FILE"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Edit configuration: sudo nano $CONFIG_FILE"
echo "2. Set external-ip: external-ip=YOUR_PUBLIC_IP/PRIVATE_IP"
echo "3. Change secret key: static-auth-secret=your-secure-key"
echo "4. Restart service: sudo systemctl restart coturn"
echo "5. Test connection: ./scripts/health-check.sh"