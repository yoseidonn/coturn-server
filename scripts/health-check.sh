#!/bin/bash
# CrewDEV TURN Server Health Check Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 CrewDEV TURN Server Health Check${NC}"
echo "====================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Function to check service status
check_service() {
    echo -e "${YELLOW}Checking coturn service...${NC}"
    if systemctl is-active --quiet coturn; then
        echo -e "${GREEN}✅ coturn service is running${NC}"
        return 0
    else
        echo -e "${RED}❌ coturn service is not running${NC}"
        return 1
    fi
}

# Function to check ports
check_ports() {
    echo -e "${YELLOW}Checking listening ports...${NC}"
    
    # Check STUN/TURN port
    if netstat -tulnp | grep -q ":3478"; then
        echo -e "${GREEN}✅ Port 3478 (STUN/TURN) is listening${NC}"
    else
        echo -e "${RED}❌ Port 3478 is not listening${NC}"
        return 1
    fi
    
    # Check TLS port
    if netstat -tulnp | grep -q ":5349"; then
        echo -e "${GREEN}✅ Port 5349 (TLS) is listening${NC}"
    else
        echo -e "${YELLOW}⚠️  Port 5349 (TLS) is not listening${NC}"
    fi
}

# Function to check configuration
check_config() {
    echo -e "${YELLOW}Checking configuration...${NC}"
    if /usr/bin/turnserver -c /etc/coturn/coturn.conf --check-config; then
        echo -e "${GREEN}✅ Configuration is valid${NC}"
        return 0
    else
        echo -e "${RED}❌ Configuration has errors${NC}"
        return 1
    fi
}

# Function to check logs
check_logs() {
    echo -e "${YELLOW}Checking recent logs...${NC}"
    if [ -f /var/log/coturn/coturn.log ]; then
        echo -e "${BLUE}Recent log entries:${NC}"
        tail -n 10 /var/log/coturn/coturn.log
    else
        echo -e "${YELLOW}⚠️  Log file not found${NC}"
    fi
}

# Function to test TURN server
test_turn() {
    echo -e "${YELLOW}Testing TURN server connectivity...${NC}"
    
    # Get external IP from config
    EXTERNAL_IP=$(grep "external-ip" /etc/coturn/coturn.conf | head -1 | cut -d'=' -f2 | tr -d ' ')
    
    if [ -z "$EXTERNAL_IP" ]; then
        echo -e "${RED}❌ external-ip not configured${NC}"
        return 1
    fi
    
    # Extract public IP
    PUBLIC_IP=$(echo $EXTERNAL_IP | cut -d'/' -f1)
    
    echo -e "${BLUE}Testing connection to $PUBLIC_IP:3478...${NC}"
    
    # Test STUN
    if timeout 5 nc -u $PUBLIC_IP 3478 < /dev/null; then
        echo -e "${GREEN}✅ STUN port is reachable${NC}"
    else
        echo -e "${RED}❌ STUN port is not reachable${NC}"
        return 1
    fi
}

# Function to check resource usage
check_resources() {
    echo -e "${YELLOW}Checking resource usage...${NC}"
    
    # Check memory usage
    MEMORY=$(ps aux | grep turnserver | grep -v grep | awk '{sum+=$6} END {print sum/1024 " MB"}')
    if [ ! -z "$MEMORY" ]; then
        echo -e "${BLUE}Memory usage: $MEMORY${NC}"
    fi
    
    # Check CPU usage
    CPU=$(ps aux | grep turnserver | grep -v grep | awk '{sum+=$3} END {print sum "%"}')
    if [ ! -z "$CPU" ]; then
        echo -e "${BLUE}CPU usage: $CPU${NC}"
    fi
}

# Function to check firewall
check_firewall() {
    echo -e "${YELLOW}Checking firewall rules...${NC}"
    
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "3478"; then
            echo -e "${GREEN}✅ UFW allows port 3478${NC}"
        else
            echo -e "${RED}❌ UFW blocks port 3478${NC}"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --list-ports | grep -q "3478"; then
            echo -e "${GREEN}✅ firewalld allows port 3478${NC}"
        else
            echo -e "${RED}❌ firewalld blocks port 3478${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No firewall detected${NC}"
    fi
}

# Run all checks
echo -e "${BLUE}Running health checks...${NC}"
echo ""

# Service status
if ! check_service; then
    echo -e "${RED}❌ Service check failed${NC}"
    exit 1
fi

# Ports
if ! check_ports; then
    echo -e "${RED}❌ Port check failed${NC}"
    exit 1
fi

# Configuration
if ! check_config; then
    echo -e "${RED}❌ Configuration check failed${NC}"
    exit 1
fi

# Logs
check_logs

# Resources
check_resources

# Firewall
check_firewall

# TURN test
if ! test_turn; then
    echo -e "${RED}❌ TURN connectivity test failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 All health checks passed!${NC}"
echo -e "${BLUE}TURN Server is healthy and ready to use.${NC}"
