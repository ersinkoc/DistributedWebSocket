param(
    [Parameter(Mandatory=$true)]
    [string]$WsUpdatesUrl,
    [Parameter(Mandatory=$true)]
    [string]$ApiKey,
    [string]$InstallPath = "C:\haproxy",
    [string]$HttpPort = "8080",
    [string]$HttpsPort = "8443",
    [string]$SslCertPath = ""
)

# Create installation directory
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null

# Download required files from repository
$files = @(
    "haproxy/haproxy.cfg",
    "haproxy/Dockerfile",
    "haproxy/update_backends.py"
)

foreach ($file in $files) {
    $destPath = Join-Path $InstallPath ($file -replace "haproxy/", "")
    New-Item -ItemType Directory -Force -Path (Split-Path $destPath) | Out-Null
    Copy-Item (Join-Path $PSScriptRoot ".." $file) $destPath -Force
}

# Create environment file
@"
WS_UPDATES_URL=$WsUpdatesUrl
API_KEY=$ApiKey
"@ | Set-Content (Join-Path $InstallPath ".env")

# Create docker-compose file
$sslVolume = ""
if ($SslCertPath) {
    $sslVolume = "      - ${SslCertPath}:/usr/local/etc/haproxy/cert.pem:ro"
}

@"
version: '3.8'

services:
  haproxy:
    build: .
    ports:
      - "${HttpPort}:8080"
      - "${HttpsPort}:8443"
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
$sslVolume
    environment:
      - WS_UPDATES_URL=$WsUpdatesUrl
      - API_KEY=$ApiKey
    restart: unless-stopped

  updater:
    build: 
      context: .
      dockerfile: Dockerfile.updater
    environment:
      - WS_UPDATES_URL=$WsUpdatesUrl
      - API_KEY=$ApiKey
      - UPDATE_INTERVAL=30
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped

networks:
  default:
    name: ws_network
"@ | Set-Content (Join-Path $InstallPath "docker-compose.yml")

Write-Host "HAProxy installation prepared at: $InstallPath"
Write-Host "HTTP Port: $HttpPort"
Write-Host "HTTPS Port: $HttpsPort"
Write-Host "To start the service:"
Write-Host "cd $InstallPath"
Write-Host "docker-compose up -d"
