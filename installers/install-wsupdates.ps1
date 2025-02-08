param(
    [string]$InstallPath = "C:\wsupdates",
    [string]$Port = "8000",
    [string]$ApiKey = (New-Guid).ToString(),
    [string]$DbPath = "C:\wsupdates\data\ws.db"
)

# Create installation directory
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $DbPath) | Out-Null

# Download required files from repository
$files = @(
    "wsupdates/src/index.php",
    "wsupdates/composer.json",
    "wsupdates/Dockerfile"
)

foreach ($file in $files) {
    $destPath = Join-Path $InstallPath ($file -replace "wsupdates/", "")
    New-Item -ItemType Directory -Force -Path (Split-Path $destPath) | Out-Null
    Copy-Item (Join-Path $PSScriptRoot ".." $file) $destPath -Force
}

# Create environment file
@"
DB_PATH=$DbPath
API_KEY=$ApiKey
"@ | Set-Content (Join-Path $InstallPath ".env")

# Create docker-compose file
@"
version: '3.8'

services:
  wsupdates:
    build: .
    environment:
      - DB_PATH=$DbPath
      - API_KEY=$ApiKey
    volumes:
      - ${DbPath}:/data/ws.db
    ports:
      - "${Port}:80"
    restart: unless-stopped

networks:
  default:
    name: ws_network
"@ | Set-Content (Join-Path $InstallPath "docker-compose.yml")

Write-Host "WSUpdates installation prepared at: $InstallPath"
Write-Host "API Key: $ApiKey"
Write-Host "To start the service:"
Write-Host "cd $InstallPath"
Write-Host "docker-compose up -d"
