#!/usr/bin/env python3

import os
import time
import requests
import logging
from typing import List, Dict
import subprocess

# Configuration
WS_UPDATES_URL = os.getenv('WS_UPDATES_URL', 'http://wsupdates.example.com')
API_KEY = os.getenv('API_KEY')
UPDATE_INTERVAL = int(os.getenv('UPDATE_INTERVAL', 60))
HAPROXY_CONFIG = '/usr/local/etc/haproxy/haproxy.cfg'

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def get_active_nodes() -> List[Dict]:
    """Fetch active nodes from WSUpdates service"""
    try:
        response = requests.get(
            f"{WS_UPDATES_URL}/nodes",
            headers={'X-API-Key': API_KEY},
            timeout=5
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        logger.error(f"Failed to fetch nodes: {e}")
        return []

def update_haproxy_config(nodes: List[Dict]) -> bool:
    """Update HAProxy configuration with active nodes"""
    try:
        # Read current config
        with open(HAPROXY_CONFIG, 'r') as f:
            config_lines = f.readlines()

        # Find ws_nodes backend section
        start_idx = -1
        end_idx = -1
        for i, line in enumerate(config_lines):
            if line.strip() == 'backend ws_nodes':
                start_idx = i
            elif start_idx != -1 and line.strip().startswith('backend'):
                end_idx = i
                break

        if start_idx == -1:
            logger.error("Could not find ws_nodes backend section")
            return False

        # Create new backend configuration
        new_config = [
            'backend ws_nodes\n',
            '    balance roundrobin\n',
            '    option forwardfor\n',
            '    option http-server-close\n',
            '    option forceclose\n',
            '    stick-table type ip size 200k expire 30m\n',
            '    stick on src\n'
        ]

        # Add server entries
        for node in nodes:
            try:
                url = node['url'].replace('http://', '').replace('https://', '')
                host, port = url.split(':')
                new_config.append(f'    server {node["id"]} {host}:{port} check\n')
            except Exception as e:
                logger.warning(f"Failed to parse node URL {node['url']}: {e}")
                continue

        # Combine configuration
        final_config = (
            config_lines[:start_idx] +
            new_config +
            config_lines[end_idx if end_idx != -1 else len(config_lines):]
        )

        # Write new configuration
        with open(HAPROXY_CONFIG, 'w') as f:
            f.writelines(final_config)

        # Reload HAProxy
        subprocess.run(['haproxy', '-c', '-f', HAPROXY_CONFIG], check=True)
        subprocess.run(['haproxy', '-sf', '$(pidof haproxy)'], shell=True, check=True)

        logger.info(f"Updated HAProxy configuration with {len(nodes)} nodes")
        return True

    except Exception as e:
        logger.error(f"Failed to update HAProxy configuration: {e}")
        return False

def main():
    """Main update loop"""
    logger.info("Starting HAProxy backend updater")
    
    while True:
        try:
            nodes = get_active_nodes()
            if nodes:
                update_haproxy_config(nodes)
            else:
                logger.warning("No active nodes found")
                
        except Exception as e:
            logger.error(f"Update cycle failed: {e}")
            
        time.sleep(UPDATE_INTERVAL)

if __name__ == '__main__':
    main()
