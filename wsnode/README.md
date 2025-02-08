# WebSocket Node Component

WSNode is a Node.js-based WebSocket server that handles client connections and message broadcasting.

## Architecture

```mermaid
graph TB
    subgraph "WSNode Component"
        WS[WebSocket Server] --> CM[Channel Manager]
        WS --> MM[Metrics Manager]
        
        subgraph "Connection Handling"
            CH[Connection Handler] --> AUTH[Authenticator]
            AUTH --> SUB[Subscription Manager]
            SUB --> BC[Broadcaster]
        end
        
        subgraph "Inter-Node Communication"
            BC --> INC[Inter-Node Comm]
            INC --> OTHER[Other Nodes]
        end
    end
    
    style WS fill:#9cf,stroke:#333
    style CM fill:#f96,stroke:#333
    style MM fill:#9f9,stroke:#333
    style CH fill:#fc9,stroke:#333
    style AUTH fill:#f9f,stroke:#333
    style BC fill:#ff9,stroke:#333
```

## Message Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant WS as WSNode
    participant CM as Channel Manager
    participant BC as Broadcaster
    participant ON as Other Nodes
    participant MM as Metrics Manager

    C->>WS: Connect
    WS->>CM: Validate Channel
    CM-->>WS: Channel OK
    C->>WS: Subscribe
    WS->>BC: Register Client
    
    Note over WS,BC: Broadcasting
    BC->>ON: Forward Message
    BC->>C: Send Message
    
    WS->>MM: Record Metrics
```

## Component State Machine

```mermaid
stateDiagram-v2
    [*] --> Starting
    Starting --> Initializing: Load Config
    Initializing --> Registering: Generate Node ID
    Registering --> Active: Register with WSUpdates
    Active --> LoadingChannels: Get Channel List
    LoadingChannels --> Ready: Channel List Loaded
    Ready --> Broadcasting: Message Received
    Broadcasting --> Ready: Message Sent
    Ready --> Active: Update Status
    Active --> Disconnected: Connection Lost
    Disconnected --> Registering: Retry
```

## Directory Structure

```
wsnode/
├── src/
│   ├── server.js          # Main WebSocket server
│   ├── channelManager.js  # Channel management
│   ├── metricsManager.js # Metrics collection
│   └── utils/            # Utility functions
├── Dockerfile            # Container configuration
└── package.json         # Dependencies
```

## Class Diagram

```mermaid
classDiagram
    class WSNode {
        +WebSocketServer server
        +ChannelManager channels
        +MetricsManager metrics
        +start()
        +stop()
        +broadcast()
    }
    
    class ChannelManager {
        +Set channels
        +validateChannel()
        +addSubscription()
        +removeSubscription()
    }
    
    class MetricsManager {
        +Map metrics
        +recordConnection()
        +recordBroadcast()
        +getMetrics()
    }
    
    class MessageHandler {
        +handleSubscribe()
        +handleUnsubscribe()
        +handleBroadcast()
    }
    
    WSNode --> ChannelManager
    WSNode --> MetricsManager
    WSNode --> MessageHandler
```

## Message Broadcasting

```mermaid
graph TD
    subgraph "Local Node"
        MSG[Message] --> VAL[Validate]
        VAL --> BC[Broadcast]
        BC --> LOCAL[Local Clients]
        BC --> FWD[Forward]
    end
    
    subgraph "Remote Nodes"
        FWD --> N1[Node 1]
        FWD --> N2[Node 2]
        FWD --> N3[Node 3]
        
        N1 --> C1[Clients]
        N2 --> C2[Clients]
        N3 --> C3[Clients]
    end
    
    style MSG fill:#f96,stroke:#333
    style BC fill:#9cf,stroke:#333
    style LOCAL fill:#9f9,stroke:#333
    style FWD fill:#f9f,stroke:#333
```

## Metrics Collection

```mermaid
graph LR
    subgraph "Node Metrics"
        CONN[Connections] --> AGG[Aggregator]
        MSG[Messages] --> AGG
        MEM[Memory] --> AGG
        CPU[CPU] --> AGG
    end
    
    subgraph "Reporting"
        AGG --> REP[Reporter]
        REP --> CFG[Config Service]
    end
    
    style AGG fill:#f96,stroke:#333
    style REP fill:#9cf,stroke:#333
    style CFG fill:#9f9,stroke:#333
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| NODE_ID | Unique node identifier | auto-generated |
| PORT | WebSocket server port | 8081 |
| WS_UPDATES_URL | Config service URL | - |
| API_KEY | Authentication key | - |

## API Endpoints

1. WebSocket: `ws://hostname:port`
2. Health: `GET /health`
3. Metrics: `GET /metrics`

## Security

1. API Key Authentication
2. Channel Access Control
3. Rate Limiting
4. Connection Validation

## Troubleshooting

1. Check logs
```bash
docker-compose logs -f wsnode
```

2. Monitor metrics
```bash
curl http://localhost:8081/metrics
```

3. Verify node registration
```bash
curl http://localhost:8081/health
```
