# PowerShell script to update HAProxy backend configuration
param(
    [string]$WsUpdatesUrl = "http://wsupdates.example.com",
    [string]$ApiKey = "",
    [string]$HaproxyConfig = "haproxy.cfg",
    [string]$BackupDir = "backups"
)

# Ensure backup directory exists
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir
}

# Create backup of current config
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = Join-Path $BackupDir "haproxy_$timestamp.cfg"
Copy-Item $HaproxyConfig $backupFile

try {
    # Get active nodes from WSUpdates service
    $headers = @{
        "X-API-Key" = $ApiKey
    }
    
    $response = Invoke-RestMethod -Uri "$WsUpdatesUrl/nodes" -Headers $headers
    
    if ($response) {
        # Read current config
        $config = Get-Content $HaproxyConfig
        
        # Find the ws_nodes backend section
        $startIndex = $config.IndexOf("backend ws_nodes")
        if ($startIndex -eq -1) {
            throw "Could not find ws_nodes backend section"
        }
        
        # Find the end of the backend section
        $endIndex = $startIndex + 1
        while ($endIndex -lt $config.Count -and -not $config[$endIndex].StartsWith("backend")) {
            $endIndex++
        }
        
        # Create new backend configuration
        $newBackend = @("backend ws_nodes",
            "    balance roundrobin",
            "    option forwardfor",
            "    option http-server-close",
            "    option forceclose",
            "    stick-table type ip size 200k expire 30m",
            "    stick on src")
            
        # Add server entries
        foreach ($node in $response) {
            $uri = [System.Uri]$node.url
            $newBackend += "    server $($node.id) $($uri.Host):$($uri.Port) check"
        }
        
        # Replace the old backend section with the new one
        $newConfig = $config[0..($startIndex-1)] + $newBackend + $config[$endIndex..($config.Count-1)]
        
        # Write the new configuration
        $newConfig | Set-Content $HaproxyConfig
        
        # Validate configuration (requires haproxy to be installed)
        $validation = haproxy -c -f $HaproxyConfig
        if ($LASTEXITCODE -ne 0) {
            throw "Invalid HAProxy configuration: $validation"
        }
        
        # Reload HAProxy (requires appropriate permissions)
        $reload = haproxy -f $HaproxyConfig -p /var/run/haproxy.pid -sf (Get-Content /var/run/haproxy.pid)
        Write-Host "HAProxy configuration updated and reloaded successfully"
    }
}
catch {
    Write-Error "Error updating HAProxy configuration: $_"
    # Restore backup
    Copy-Item $backupFile $HaproxyConfig
    exit 1
}
