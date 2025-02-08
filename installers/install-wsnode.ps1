param(
    [Parameter(Mandatory=$true)]
    [string]$WsUpdatesUrl,
    [Parameter(Mandatory=$true)]
    [string]$ApiKey,
    [string]$InstallPath = "C:\wsnode",
    [string]$Port = "8081",
    [string]$NodeId = (New-Guid).ToString()
)

# Create installation directory
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null

# Download required files from repository
$files = @(
    "wsnode/src/server.js",
    "wsnode/package.json",
    "wsnode/Dockerfile"
)

foreach ($file in $files) {
    $destPath = Join-Path $InstallPath ($file -replace "wsnode/", "")
    New-Item -ItemType Directory -Force -Path (Split-Path $destPath) | Out-Null
    Copy-Item (Join-Path $PSScriptRoot ".." $file) $destPath -Force
}

# Create environment file
@"
NODE_ID=$NodeId
PORT=$Port
WS_UPDATES_URL=$WsUpdatesUrl
API_KEY=$ApiKey
"@ | Set-Content (Join-Path $InstallPath ".env")

# Create docker-compose file
@"
version: '3.8'

services:
  wsnode:
    build: .
    environment:
      - NODE_ID=$NodeId
      - PORT=$Port
      - WS_UPDATES_URL=$WsUpdatesUrl
      - API_KEY=$ApiKey
    ports:
      - "${Port}:${Port}"
    restart: unless-stopped

networks:
  default:
    name: ws_network
"@ | Set-Content (Join-Path $InstallPath "docker-compose.yml")

Write-Host "WSNode installation prepared at: $InstallPath"
Write-Host "Node ID: $NodeId"
Write-Host "Port: $Port"
Write-Host "To start the service:"
Write-Host "cd $InstallPath"
Write-Host "docker-compose up -d"
