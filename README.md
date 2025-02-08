# Distributed WebSocket Management System

A scalable, distributed WebSocket server management system that enables load balancing and seamless message broadcasting across multiple WebSocket nodes without centralized message brokers.

## Architecture Overview

The system consists of three main components:

1. **HAProxy Load Balancer**
   - Distributes incoming WebSocket connections across multiple WSNodes
   - Auto-updates server configuration via cron job
   - Handles SSL termination and connection persistence

2. **WSNode (WebSocket Nodes)**
   - NodeJS-based WebSocket servers
   - Can be deployed across different networks/locations
   - Each node has a unique identifier
   - Communicates with other nodes via HTTP
   - Handles client connections and message broadcasting
   - Provides metrics and health monitoring

3. **WSUpdates Service**
   - PHP-based central configuration service
   - Uses SQLite for storage
   - Maintains node registry and channel configurations
   - Provides node discovery and configuration endpoints

## Communication Flow

```
[Clients] <-> [HAProxy] <-> [WSNodes] <-> [Other WSNodes]
                              ^
                              |
                        [WSUpdates Service]
```

1. **Client Connection Flow**
   - Clients connect through HAProxy (ws.example.com)
   - HAProxy routes to available WSNode
   - Clients subscribe to channels
   - Clients cannot broadcast messages

2. **Broadcast Flow**
   - Protected API endpoint receives broadcast message
   - Receiving node forwards to all connected nodes
   - Each node broadcasts to subscribed clients
   - No central message broker involved

3. **Node Discovery Flow**
   - New node fetches configuration from WSUpdates
   - Node announces presence to other nodes
   - Periodic configuration refresh from WSUpdates
   - HAProxy updates backend configuration via cron

## Directory Structure

```
/
├── haproxy/         # HAProxy configuration and scripts
├── wsnode/          # NodeJS WebSocket server
└── wsupdates/       # PHP configuration service
```

## Component Details

### HAProxy Configuration
- Sticky sessions enabled
- Health checking
- SSL termination
- Dynamic backend updates
- Configuration update script

### WSNode
- Dockerized NodeJS application
- Configurable ports and settings
- Unique node identification
- Inter-node communication
- Metrics and monitoring
- Channel subscription management

### WSUpdates
- PHP/SQLite based service
- Node registry management
- Channel configuration
- Security and authentication
- API documentation

## Development Guidelines

1. **Code Style**
   - Follow consistent code formatting
   - Write comprehensive documentation
   - Use meaningful variable/function names
   - Include inline comments for complex logic

2. **Security**
   - Implement authentication for admin endpoints
   - Secure inter-node communication
   - Validate all inputs
   - Use environment variables for sensitive data

3. **Testing**
   - Write unit tests for core functionality
   - Include integration tests
   - Test scaling and failover scenarios
   - Load testing guidelines

4. **Deployment**
   - Docker-based deployment
   - Environment configuration
   - Monitoring setup
   - Backup procedures

## Configuration

Each component requires specific configuration:

### HAProxy
```conf
# Example configuration in haproxy/
frontend ws_frontend
    bind *:443 ssl crt /path/to/cert.pem
    mode http
    option forwardfor
    default_backend ws_backend
```

### WSNode
```env
# Example .env configuration
NODE_ID=unique_id
PORT=8080
WS_UPDATES_URL=https://wsupdates.example.com
```

### WSUpdates
```env
# Example .env configuration
DB_PATH=/path/to/sqlite.db
API_KEY=secure_key
```

## Getting Started

1. Clone the repository
2. Set up WSUpdates service
3. Configure and start HAProxy
4. Deploy WSNodes
5. Configure environment variables
6. Test the setup

## Monitoring and Maintenance

- Node health checks
- Connection metrics
- Message throughput
- System resources
- Error logging

## License

MIT License

## Contributing

1. Fork the repository
2. Create feature branch
3. Submit pull request
4. Follow code guidelines
