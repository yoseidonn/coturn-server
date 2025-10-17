#!/bin/bash
# CrewDEV TURN Server Configuration Script
# Interactive configuration for coturn settings

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}⚙️  CrewDEV TURN Server Configuration${NC}"
echo "====================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

CONFIG_FILE="/etc/coturn/coturn.conf"
BACKUP_FILE="/etc/coturn/coturn.conf.backup"

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Backing up existing configuration...${NC}"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"
fi

# Function to get external IP
get_external_ip() {
    echo -e "${YELLOW}Detecting external IP...${NC}"
    
    # Try multiple methods to get external IP
    EXTERNAL_IP=""
    
    # Method 1: curl
    if command -v curl &> /dev/null; then
        EXTERNAL_IP=$(curl -s --max-time 5 https://ipinfo.io/ip 2>/dev/null)
    fi
    
    # Method 2: wget
    if [ -z "$EXTERNAL_IP" ] && command -v wget &> /dev/null; then
        EXTERNAL_IP=$(wget -qO- --timeout=5 https://ipinfo.io/ip 2>/dev/null)
    fi
    
    # Method 3: dig
    if [ -z "$EXTERNAL_IP" ] && command -v dig &> /dev/null; then
        EXTERNAL_IP=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)
    fi
    
    if [ -z "$EXTERNAL_IP" ]; then
        echo -e "${RED}❌ Could not detect external IP automatically${NC}"
        echo -e "${YELLOW}Please enter your external IP manually:${NC}"
        read -p "External IP: " EXTERNAL_IP
    else
        echo -e "${GREEN}✅ Detected external IP: $EXTERNAL_IP${NC}"
        read -p "Use this IP? (y/n): " confirm
        if [[ $confirm != "y" ]]; then
            read -p "Enter external IP: " EXTERNAL_IP
        fi
    fi
    
    # Get private IP
    PRIVATE_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
    echo -e "${BLUE}Private IP: $PRIVATE_IP${NC}"
    
    echo "$EXTERNAL_IP/$PRIVATE_IP"
}

# Function to generate secret key
generate_secret() {
    echo -e "${YELLOW}Generating secure secret key...${NC}"
    openssl rand -base64 32
}

# Function to configure basic settings
configure_basic() {
    echo -e "${YELLOW}Configuring basic settings...${NC}"
    
    # Get external IP
    EXTERNAL_IP=$(get_external_ip)
    
    # Generate secret
    SECRET_KEY=$(generate_secret)
    
    # Get realm
    read -p "Enter realm (default: crewdev.com): " REALM
    REALM=${REALM:-crewdev.com}
    
    # Get server name
    read -p "Enter server name (default: crewdev-turn): " SERVER_NAME
    SERVER_NAME=${SERVER_NAME:-crewdev-turn}
    
    # Create new config
    cat > "$CONFIG_FILE" << EOF
# CrewDEV TURN Server Configuration
# Generated on $(date)

# Basic server settings
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
listening-ip=::0

# External IP configuration
external-ip=$EXTERNAL_IP

# Server identification
realm=$REALM
server-name=$SERVER_NAME

# Authentication
use-auth-secret
static-auth-secret=$SECRET_KEY

# Logging
log-file=/var/log/coturn/coturn.log
verbose
no-stdout-log

# Security settings
no-multicast-peers
no-cli
no-tlsv1
no-tlsv1_1
no-tlsv1_2

# Performance settings
total-quota=1000
user-quota=50
stale-nonce=600
no-tcp-relay

# RTP/RTCP port range
min-port=49152
max-port=65535

# Network restrictions
allowed-peer-ip=0.0.0.0-255.255.255.255
denied-peer-ip=127.0.0.1-127.255.255.255
denied-peer-ip=::1
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255

# Enable STUN and TURN
stun-only
no-multicast-peers

# Relay settings
relay-ip=0.0.0.0
relay-ip=::0

# Additional security
no-loopback-peers
no-multicast-peers
no-cli
no-tlsv1
no-tlsv1_1
no-tlsv1_2

# Bandwidth limits
total-quota=1000
user-quota=50
EOF

    echo -e "${GREEN}✅ Basic configuration created${NC}"
    echo -e "${BLUE}External IP: $EXTERNAL_IP${NC}"
    echo -e "${BLUE}Realm: $REALM${NC}"
    echo -e "${BLUE}Secret Key: $SECRET_KEY${NC}"
}

# Function to configure SSL
configure_ssl() {
    echo -e "${YELLOW}Configuring SSL/TLS...${NC}"
    
    read -p "Enable SSL/TLS? (y/n): " enable_ssl
    if [[ $enable_ssl == "y" ]]; then
        echo -e "${YELLOW}SSL certificate setup:${NC}"
        echo "1. Use existing certificates"
        echo "2. Generate self-signed certificates"
        echo "3. Skip SSL setup"
        
        read -p "Choose option (1-3): " ssl_option
        
        case $ssl_option in
            1)
                read -p "Certificate file path: " CERT_FILE
                read -p "Private key file path: " KEY_FILE
                
                if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
                    echo "cert=$CERT_FILE" >> "$CONFIG_FILE"
                    echo "pkey=$KEY_FILE" >> "$CONFIG_FILE"
                    echo -e "${GREEN}✅ SSL certificates configured${NC}"
                else
                    echo -e "${RED}❌ Certificate files not found${NC}"
                fi
                ;;
            2)
                echo -e "${YELLOW}Generating self-signed certificates...${NC}"
                mkdir -p /etc/ssl/coturn
                
                openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/coturn/key.pem -out /etc/ssl/coturn/cert.pem -days 365 -nodes -subj "/C=US/ST=State/L=City/O=Organization/CN=crewdev-turn"
                
                echo "cert=/etc/ssl/coturn/cert.pem" >> "$CONFIG_FILE"
                echo "pkey=/etc/ssl/coturn/key.pem" >> "$CONFIG_FILE"
                
                chown coturn:coturn /etc/ssl/coturn/*
                chmod 600 /etc/ssl/coturn/key.pem
                chmod 644 /etc/ssl/coturn/cert.pem
                
                echo -e "${GREEN}✅ Self-signed certificates generated${NC}"
                ;;
            3)
                echo -e "${YELLOW}SSL setup skipped${NC}"
                ;;
        esac
    fi
}

# Function to configure advanced settings
configure_advanced() {
    echo -e "${YELLOW}Configuring advanced settings...${NC}"
    
    # Bandwidth limits
    read -p "Total quota (default: 1000): " TOTAL_QUOTA
    TOTAL_QUOTA=${TOTAL_QUOTA:-1000}
    
    read -p "User quota (default: 50): " USER_QUOTA
    USER_QUOTA=${USER_QUOTA:-50}
    
    # Port range
    read -p "Min port (default: 49152): " MIN_PORT
    MIN_PORT=${MIN_PORT:-49152}
    
    read -p "Max port (default: 65535): " MAX_PORT
    MAX_PORT=${MAX_PORT:-65535}
    
    # Update config
    sed -i "s/total-quota=.*/total-quota=$TOTAL_QUOTA/" "$CONFIG_FILE"
    sed -i "s/user-quota=.*/user-quota=$USER_QUOTA/" "$CONFIG_FILE"
    sed -i "s/min-port=.*/min-port=$MIN_PORT/" "$CONFIG_FILE"
    sed -i "s/max-port=.*/max-port=$MAX_PORT/" "$CONFIG_FILE"
    
    echo -e "${GREEN}✅ Advanced settings configured${NC}"
}

# Main configuration flow
echo -e "${BLUE}Configuration Options:${NC}"
echo "1. Basic configuration (recommended)"
echo "2. Basic + SSL/TLS"
echo "3. Basic + SSL/TLS + Advanced"
echo "4. Custom configuration"

read -p "Choose option (1-4): " config_option

case $config_option in
    1)
        configure_basic
        ;;
    2)
        configure_basic
        configure_ssl
        ;;
    3)
        configure_basic
        configure_ssl
        configure_advanced
        ;;
    4)
        echo -e "${YELLOW}Opening configuration file for manual editing...${NC}"
        nano "$CONFIG_FILE"
        ;;
esac

# Validate configuration
echo -e "${YELLOW}Validating configuration...${NC}"
if /usr/bin/turnserver -c "$CONFIG_FILE" --check-config; then
    echo -e "${GREEN}✅ Configuration is valid${NC}"
else
    echo -e "${RED}❌ Configuration has errors${NC}"
    echo -e "${YELLOW}Restoring backup...${NC}"
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
fi

# Restart service
echo -e "${YELLOW}Restarting coturn service...${NC}"
systemctl restart coturn

if systemctl is-active --quiet coturn; then
    echo -e "${GREEN}✅ coturn service restarted successfully${NC}"
else
    echo -e "${RED}❌ Failed to restart coturn service${NC}"
    systemctl status coturn
    exit 1
fi

echo -e "\n${GREEN}🎉 Configuration completed successfully!${NC}"
echo -e "${BLUE}Run './scripts/health-check.sh' to verify the setup.${NC}"
