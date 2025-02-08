# Distributed WebSocket Management System

A scalable, distributed WebSocket server management system that enables load balancing and seamless message broadcasting across multiple WebSocket nodes without centralized message brokers.

## System Architecture

```mermaid
graph TB
    subgraph External
        C[Clients] --> HAP[HAProxy]
        API[Backend API] --> HAP
    end
    
    subgraph Load Balancer
        HAP --> |Load Balance| WS1
        HAP --> |Load Balance| WS2
        HAP --> |Load Balance| WS3
    end
    
    subgraph WSNodes
        WS1[WSNode 1]
        WS2[WSNode 2]
        WS3[WSNode 3]
        WS1 <--> |Inter-node Comm| WS2
        WS2 <--> |Inter-node Comm| WS3
        WS3 <--> |Inter-node Comm| WS1
    end
    
    subgraph Management
        WSU[WSUpdates Service]
        DB[(SQLite DB)]
        WSU --> DB
        WS1 --> |Register/Metrics| WSU
        WS2 --> |Register/Metrics| WSU
        WS3 --> |Register/Metrics| WSU
        HAP --> |Get Node List| WSU
    end

    style C fill:#f9f,stroke:#333,stroke-width:2px
    style API fill:#bbf,stroke:#333,stroke-width:2px
    style HAP fill:#fb7,stroke:#333,stroke-width:2px
    style WS1 fill:#bfb,stroke:#333,stroke-width:2px
    style WS2 fill:#bfb,stroke:#333,stroke-width:2px
    style WS3 fill:#bfb,stroke:#333,stroke-width:2px
    style WSU fill:#ff9,stroke:#333,stroke-width:2px
    style DB fill:#ddd,stroke:#333,stroke-width:2px
```

## Message Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant HAP as HAProxy
    participant WS1 as WSNode 1
    participant WS2 as WSNode 2
    participant API as Backend API

    C->>HAP: WebSocket Connection
    HAP->>WS1: Route to Node
    C->>WS1: Subscribe to Channel
    Note over WS1: Store Subscription
    
    API->>HAP: Broadcast Message
    HAP->>WS1: Route Message
    
    WS1->>WS2: Forward Message
    Note over WS1,WS2: Inter-node Communication
    
    par Broadcast to Subscribers
        WS1->>C: Send Message
        WS2->>C: Send Message (if subscribed)
    end
```

## Component Structure

```mermaid
classDiagram
    class WSNode {
        +MetricsManager metrics
        +ChannelManager channels
        +Map~string,WebSocket~ clients
        +Map~string,Set~ subscriptions
        +handleConnection()
        +handleSubscription()
        +broadcastMessage()
        +forwardMessage()
    }
    
    class MetricsManager {
        +Map metrics
        +recordBroadcast()
        +recordSubscription()
        +updateMetrics()
        +getMetrics()
    }
    
    class ChannelManager {
        +Set validChannels
        +loadChannels()
        +isValidChannel()
        +recordSubscription()
    }
    
    class WSUpdates {
        +SQLiteDB db
        +registerNode()
        +updateNodeStatus()
        +getActiveNodes()
        +storeMetrics()
    }
    
    class HAProxy {
        +List backends
        +updateBackends()
        +loadBalance()
        +healthCheck()
    }
    
    WSNode --> MetricsManager
    WSNode --> ChannelManager
    WSNode ..> WSUpdates
    HAProxy ..> WSUpdates
```

## Node Discovery Process

```mermaid
stateDiagram-v2
    [*] --> Starting
    Starting --> Initializing: Load Config
    Initializing --> Registering: Generate Node ID
    Registering --> Active: Register with WSUpdates
    Active --> LoadingChannels: Get Channel List
    LoadingChannels --> Ready: Channel List Loaded
    Ready --> Active: Update Status
    Active --> Disconnected: Connection Lost
    Disconnected --> Registering: Retry Connection
    Ready --> [*]: Shutdown
```

## Broadcast Message Flow

```mermaid
flowchart TD
    A[API Request] --> B{HAProxy}
    B --> C[WSNode 1]
    B --> D[WSNode 2]
    B --> E[WSNode 3]
    
    C --> F{Forward to Other Nodes}
    F --> D
    F --> E
    
    C --> G[Local Subscribers]
    D --> H[Local Subscribers]
    E --> I[Local Subscribers]
    
    style A fill:#f9f
    style B fill:#fb7
    style C fill:#bfb
    style D fill:#bfb
    style E fill:#bfb
    style F fill:#ff9
    style G fill:#ddd
    style H fill:#ddd
    style I fill:#ddd
```

## Metrics Collection

```mermaid
graph LR
    subgraph Nodes
        N1[WSNode 1] --> |Metrics| M1[Metrics Manager 1]
        N2[WSNode 2] --> |Metrics| M2[Metrics Manager 2]
        N3[WSNode 3] --> |Metrics| M3[Metrics Manager 3]
    end
    
    subgraph Collection
        M1 --> |Report| WSU
        M2 --> |Report| WSU
        M3 --> |Report| WSU
        WSU[WSUpdates] --> DB[(SQLite)]
    end
    
    subgraph Monitoring
        DB --> |Query| API[Metrics API]
        API --> |Display| DASH[Dashboard]
    end
    
    style N1 fill:#bfb
    style N2 fill:#bfb
    style N3 fill:#bfb
    style M1 fill:#ff9
    style M2 fill:#ff9
    style M3 fill:#ff9
    style WSU fill:#fb7
    style DB fill:#ddd
    style API fill:#f9f
    style DASH fill:#bbf
```

## Development Guidelines

- All code and comments in English
- Clean, modular code structure
- Environment-specific configurations
- Docker-first deployment approach
- Comprehensive logging and monitoring

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
