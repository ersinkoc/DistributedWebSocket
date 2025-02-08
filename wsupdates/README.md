# WSUpdates Configuration Service

WSUpdates is a PHP-based configuration service that manages node registry and channel configurations for the WebSocket Management System.

## Architecture

```mermaid
graph TB
    subgraph "WSUpdates Service"
        API[REST API] --> REG[Node Registry]
        API --> CFG[Config Manager]
        API --> MET[Metrics Collector]
        
        subgraph "Storage"
            REG --> DB[(SQLite DB)]
            CFG --> DB
            MET --> DB
        end
    end
    
    subgraph "External Services"
        N1[Node 1] --> API
        N2[Node 2] --> API
        N3[Node 3] --> API
        HAP[HAProxy] --> API
    end
    
    style API fill:#f96,stroke:#333
    style REG fill:#9cf,stroke:#333
    style CFG fill:#9f9,stroke:#333
    style MET fill:#ff9,stroke:#333
    style DB fill:#f9f,stroke:#333
```

## Data Flow

```mermaid
sequenceDiagram
    participant N as WSNode
    participant API as REST API
    participant REG as Registry
    participant DB as SQLite
    participant HAP as HAProxy

    N->>API: Register Node
    API->>REG: Process Registration
    REG->>DB: Store Node Info
    
    HAP->>API: Get Active Nodes
    API->>DB: Query Nodes
    DB-->>API: Node List
    API-->>HAP: Active Nodes
    
    N->>API: Report Metrics
    API->>DB: Store Metrics
```

## Component States

```mermaid
stateDiagram-v2
    [*] --> Starting
    Starting --> InitDB: Create Tables
    InitDB --> Ready: DB Ready
    
    Ready --> Processing: Request Received
    Processing --> Validating: Auth Check
    Validating --> Executing: Auth OK
    Executing --> Processing: Response Sent
    
    Processing --> Ready: Request Complete
    Validating --> Error: Auth Failed
    Executing --> Error: Execution Failed
    Error --> Ready: Error Handled
```

## Database Schema

```mermaid
erDiagram
    NODES {
        string node_id PK
        string hostname
        int port
        timestamp last_seen
        string status
    }
    
    CHANNELS {
        string channel_id PK
        string name
        json config
        boolean active
    }
    
    METRICS {
        int metric_id PK
        string node_id FK
        string metric_type
        float value
        timestamp recorded_at
    }
    
    NODES ||--o{ METRICS : reports
    CHANNELS ||--o{ NODES : subscribes
```

## API Structure

```mermaid
graph LR
    subgraph "Node Management"
        REG["Nodes API"] --> ADD["Register<br/>/nodes/register"]
        REG --> UPD["Update<br/>/nodes/update"]
        REG --> LST["List<br/>/nodes/list"]
    end
    
    subgraph "Channel Management"
        CH["Channels API"] --> CHA["Create<br/>/channels/create"]
        CH --> CHU["Update<br/>/channels/update"]
        CH --> CHL["List<br/>/channels/list"]
    end
    
    subgraph "Metrics"
        MET["Metrics API"] --> REP["Report<br/>/metrics/report"]
        MET --> AGG["Aggregate<br/>/metrics/aggregate"]
    end
    
    style REG fill:#f96,stroke:#333
    style CH fill:#9cf,stroke:#333
    style MET fill:#ff9,stroke:#333
```

## Directory Structure

```
wsupdates/
├── src/
│   ├── index.php        # Main application
│   ├── config/          # Configuration
│   ├── controllers/     # Request handlers
│   └── models/          # Data models
├── Dockerfile          # Container configuration
└── composer.json      # Dependencies
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| DB_PATH | SQLite database path | /data/ws.db |
| API_KEY | Authentication key | - |

## API Endpoints

### Node Management
- `POST /nodes/register` - Register new node
- `PUT /nodes/update` - Update node status
- `GET /nodes/list` - List active nodes

### Channel Management
- `POST /channels/create` - Create channel
- `PUT /channels/update` - Update channel
- `GET /channels/list` - List channels

### Metrics
- `POST /metrics/report` - Report node metrics
- `GET /metrics/aggregate` - Get aggregated metrics

## Security

```mermaid
graph TD
    subgraph "Security Layers"
        AUTH[API Key Auth] --> VAL[Input Validation]
        VAL --> ACL[Access Control]
        ACL --> RATE[Rate Limiting]
    end
    
    subgraph "Data Protection"
        RATE --> SANIT[Sanitization]
        SANIT --> STORE[Secure Storage]
    end
    
    style AUTH fill:#f96,stroke:#333
    style VAL fill:#9cf,stroke:#333
    style ACL fill:#9f9,stroke:#333
    style RATE fill:#ff9,stroke:#333
```

## Monitoring

```mermaid
graph LR
    subgraph "System Metrics"
        CPU[CPU Usage] --> AGG[Aggregator]
        MEM[Memory] --> AGG
        DISK[Disk I/O] --> AGG
    end
    
    subgraph "Application Metrics"
        REQ[Requests] --> APP[App Monitor]
        ERR[Errors] --> APP
        LAT[Latency] --> APP
    end
    
    AGG --> DASH[Dashboard]
    APP --> DASH
    
    style AGG fill:#f96,stroke:#333
    style APP fill:#9cf,stroke:#333
    style DASH fill:#ff9,stroke:#333
```

## Troubleshooting

1. Check logs
```bash
docker-compose logs -f wsupdates
```

2. Verify database
```bash
docker-compose exec wsupdates sqlite3 /data/ws.db .tables
```

3. Test API
```bash
curl -H "X-API-Key: your_key" http://localhost:8000/health
```
