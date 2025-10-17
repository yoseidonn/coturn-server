#!/bin/bash
# CrewDEV TURN Server Setup Script
# Installs and configures coturn for WebRTC NAT traversal

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 CrewDEV TURN Server Setup${NC}"
echo "=================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo -e "${RED}Cannot detect OS version${NC}"
    exit 1
fi

echo -e "${YELLOW}Detected OS: $OS $VER${NC}"

# Install coturn
echo -e "${YELLOW}Installing coturn...${NC}"
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    apt update
    apt install -y coturn
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
    yum install -y coturn
else
    echo -e "${RED}Unsupported OS: $OS${NC}"
    exit 1
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p /etc/coturn
mkdir -p /var/log/coturn
mkdir -p /var/lib/coturn

# Copy configuration
echo -e "${YELLOW}Installing configuration...${NC}"
cp coturn.conf /etc/coturn/coturn.conf
chown coturn:coturn /etc/coturn/coturn.conf
chmod 644 /etc/coturn/coturn.conf

# Create log directory
chown coturn:coturn /var/log/coturn
chmod 755 /var/log/coturn

# Create systemd service
echo -e "${YELLOW}Creating systemd service...${NC}"
cat > /etc/systemd/system/coturn.service << EOF
[Unit]
Description=coTURN TURN Server for CrewDEV
Documentation=https://github.com/coturn/coturn
After=network.target
Wants=network.target

[Service]
Type=simple
User=coturn
Group=coturn
ExecStart=/usr/bin/turnserver -c /etc/coturn/coturn.conf
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=coturn

# Security settings
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

# Enable and start service
echo -e "${YELLOW}Starting coturn service...${NC}"
systemctl daemon-reload
systemctl enable coturn
systemctl start coturn

# Check status
if systemctl is-active --quiet coturn; then
    echo -e "${GREEN}✅ coturn service started successfully${NC}"
else
    echo -e "${RED}❌ Failed to start coturn service${NC}"
    systemctl status coturn
    exit 1
fi

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
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

# Test configuration
echo -e "${YELLOW}Testing configuration...${NC}"
if /usr/bin/turnserver -c /etc/coturn/coturn.conf --check-config; then
    echo -e "${GREEN}✅ Configuration is valid${NC}"
else
    echo -e "${RED}❌ Configuration has errors${NC}"
    exit 1
fi

# Display status
echo -e "\n${BLUE}📊 TURN Server Status${NC}"
echo "=================="
systemctl status coturn --no-pager -l

echo -e "\n${BLUE}🔧 Next Steps${NC}"
echo "============="
echo "1. Edit configuration: sudo nano /etc/coturn/coturn.conf"
echo "2. Set external-ip: external-ip=YOUR_PUBLIC_IP/PRIVATE_IP"
echo "3. Change secret key: static-auth-secret=your-secure-key"
echo "4. Restart service: sudo systemctl restart coturn"
echo "5. Test connection: ./scripts/health-check.sh"

echo -e "\n${GREEN}🎉 TURN Server setup completed!${NC}"
