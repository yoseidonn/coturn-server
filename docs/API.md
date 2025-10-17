# TURN Server API Reference

## Overview

The CrewDEV TURN server provides WebRTC NAT traversal services using the standard TURN protocol. This document covers the API endpoints and configuration options.

## 🔌 Connection Endpoints

### STUN/TURN Endpoint
```
turn:your-server.com:3478
turns:your-server.com:5349 (TLS)
```

### Authentication
- **Method**: Long-term credential mechanism
- **Username**: Static username (configurable)
- **Password**: Shared secret key

## ⚙️ Configuration API

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `TURN_HOST` | TURN server hostname | `localhost` | Yes |
| `TURN_PORT` | TURN server port | `3478` | Yes |
| `TURN_SECRET` | Authentication secret | - | Yes |
| `TURN_REALM` | Server realm | `crewdev.com` | No |
| `TURN_USERNAME` | Static username | `crewdev` | No |

## 🔧 Client Integration

### JavaScript WebRTC
```javascript
const peerConnection = new RTCPeerConnection({
    iceServers: [
        {
            urls: 'stun:stun.l.google.com:19302'
        },
        {
            urls: 'turn:your-turn-server.com:3478',
            username: 'crewdev',
            credential: 'your-secret-key'
        }
    ]
});
```

### FastAPI Backend Integration
```python
from fastapi import FastAPI
import os

app = FastAPI()

@app.get("/media/turn-credentials")
async def get_turn_credentials():
    """Provide TURN server credentials to clients"""
    return {
        "iceServers": [
            {
                "urls": "stun:stun.l.google.com:19302"
            },
            {
                "urls": f"turn:{os.getenv('TURN_HOST')}:{os.getenv('TURN_PORT')}",
                "username": os.getenv('TURN_USERNAME', 'crewdev'),
                "credential": os.getenv('TURN_SECRET')
            }
        ]
    }
```
