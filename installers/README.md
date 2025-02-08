# Standalone Installation Guide

This directory contains standalone installers for each component of the WebSocket Management System. Each component can be installed and run independently on different machines.

## Prerequisites

- Docker
- PowerShell (Windows) or Bash (Linux)
- Network connectivity between components

## Components

### 1. WSUpdates Service

The central configuration service that manages node registry and channel configurations.

```powershell
# Windows
.\install-wsupdates.ps1 -InstallPath C:\wsupdates -Port 8000

# Linux
./install-wsupdates.sh --install-path /opt/wsupdates --port 8000
```

### 2. WSNode

Individual WebSocket server nodes. You can install multiple instances on different machines.

```powershell
# Windows
.\install-wsnode.ps1 -WsUpdatesUrl "http://config-server:8000" -ApiKey "your-api-key" -Port 8081

# Linux
./install-wsnode.sh --ws-updates-url "http://config-server:8000" --api-key "your-api-key" --port 8081
```

### 3. HAProxy Load Balancer

The load balancer that distributes traffic across WSNodes.

```powershell
# Windows
.\install-haproxy.ps1 -WsUpdatesUrl "http://config-server:8000" -ApiKey "your-api-key" -HttpPort 8080 -HttpsPort 8443

# Linux
./install-haproxy.sh --ws-updates-url "http://config-server:8000" --api-key "your-api-key" --http-port 8080 --https-port 8443
```

## Installation Order

1. First install WSUpdates service
2. Note the API key generated
3. Install WSNodes using the WSUpdates URL and API key
4. Install HAProxy using the same WSUpdates URL and API key

## Example Deployment Scenarios

### 1. Single Machine Development

```powershell
# Install all components on one machine
.\install-wsupdates.ps1 -Port 8000
$apiKey = Get-Content C:\wsupdates\.env | Select-String "API_KEY" | ForEach-Object { $_ -split "=" | Select-Object -Last 1 }

.\install-wsnode.ps1 -WsUpdatesUrl "http://localhost:8000" -ApiKey $apiKey -Port 8081
.\install-wsnode.ps1 -WsUpdatesUrl "http://localhost:8000" -ApiKey $apiKey -Port 8082

.\install-haproxy.ps1 -WsUpdatesUrl "http://localhost:8000" -ApiKey $apiKey
```

### 2. Distributed Production

```powershell
# On config server
.\install-wsupdates.ps1 -Port 8000

# On node servers
.\install-wsnode.ps1 -WsUpdatesUrl "http://config-server:8000" -ApiKey "your-api-key" -Port 8081

# On load balancer
.\install-haproxy.ps1 -WsUpdatesUrl "http://config-server:8000" -ApiKey "your-api-key" -SslCertPath "path/to/cert.pem"
```

## Verification

After installation, verify each component:

1. WSUpdates Service:
```bash
curl http://localhost:8000/health
```

2. WSNode:
```bash
curl http://localhost:8081/health
```

3. HAProxy:
```bash
curl http://localhost:8080/stats
```

## Troubleshooting

1. Check component logs:
```bash
docker-compose logs -f
```

2. Verify network connectivity:
```bash
docker network inspect ws_network
```

3. Check environment variables:
```bash
docker-compose config
```

## Maintenance

### Updating Components

```bash
cd <component-path>
docker-compose pull
docker-compose up -d
```

### Backup

```bash
# WSUpdates database backup
cd <wsupdates-path>
docker-compose exec wsupdates tar czf /backup.tar.gz /data/ws.db
```

### Scaling

To add more WSNodes:
```powershell
# Install additional nodes
.\install-wsnode.ps1 -WsUpdatesUrl "http://config-server:8000" -ApiKey "your-api-key" -Port 8083
```

HAProxy will automatically detect and include new nodes in load balancing.
