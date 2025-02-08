# HAProxy Load Balancer Component

HAProxy component handles load balancing and routing for the WebSocket Management System.

## Architecture

```mermaid
graph TB
    subgraph "HAProxy Component"
        LB[HAProxy Server] --> UPDATER[Backend Updater]
        UPDATER --> CFG[haproxy.cfg]
        
        subgraph "Traffic Flow"
            CLIENT[Client] --> SSL[SSL Termination]
            SSL --> ROUTER[Request Router]
            ROUTER --> WS[WebSocket Backend]
            ROUTER --> HTTP[HTTP Backend]
        end
        
        subgraph "Health Checks"
            HC[Health Checker] --> N1[Node 1]
            HC --> N2[Node 2]
            HC --> N3[Node 3]
        end
    end
    
    style LB fill:#f96,stroke:#333
    style UPDATER fill:#9cf,stroke:#333
    style CFG fill:#fc9,stroke:#333
    style CLIENT fill:#ccc,stroke:#333
    style SSL fill:#9f9,stroke:#333
    style ROUTER fill:#f9f,stroke:#333
    style HC fill:#ff9,stroke:#333
```

## Component Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant SSL as SSL Termination
    participant LB as Load Balancer
    participant HC as Health Checker
    participant WS as WSNode
    participant CFG as Config Service

    C->>SSL: WSS Connection
    SSL->>LB: WS Connection
    LB->>HC: Check Node Health
    HC->>WS: Health Check
    WS-->>HC: Status OK
    HC-->>LB: Node Available
    LB->>WS: Route Connection
    
    loop Backend Updates
        CFG->>LB: Node List Update
        LB->>HC: Verify Nodes
    end
```

## Configuration Flow

```mermaid
stateDiagram-v2
    [*] --> Starting
    Starting --> LoadingConfig: Read haproxy.cfg
    LoadingConfig --> FetchingNodes: Contact WSUpdates
    FetchingNodes --> HealthChecks: Verify Nodes
    HealthChecks --> Ready: All Checks Pass
    Ready --> Routing: Accept Traffic
    
    Routing --> HealthChecks: Periodic Check
    HealthChecks --> FetchingNodes: Node Failure
    
    Ready --> Reloading: Config Update
    Reloading --> Ready: Reload Success
    Reloading --> Error: Reload Failure
    Error --> LoadingConfig: Retry
```

## Directory Structure

```
haproxy/
├── Dockerfile           # HAProxy container configuration
├── haproxy.cfg         # Main HAProxy configuration
├── update_backends.py  # Dynamic backend updater
└── certs/             # SSL certificates (optional)
```

## Configuration Parameters

### HAProxy Configuration

```conf
# Frontend settings
frontend http-in
    bind *:8080
    bind *:8443 ssl crt /certs/cert.pem

# Backend settings
backend ws_backend
    balance roundrobin
    option http-server-close
    option forwardfor
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| WS_UPDATES_URL | WSUpdates service URL | - |
| API_KEY | Authentication key | - |
| UPDATE_INTERVAL | Backend update interval | 30s |

## Metrics and Monitoring

```mermaid
graph LR
    subgraph "HAProxy Stats"
        STATS[Stats Page] --> CONN[Connections]
        STATS --> BYTES[Bytes Transferred]
        STATS --> HEALTH[Backend Health]
    end
    
    subgraph "Prometheus Metrics"
        PROM[Prometheus] --> RPS[Requests/Sec]
        PROM --> LAT[Latency]
        PROM --> ERR[Errors]
    end
    
    style STATS fill:#f96,stroke:#333
    style PROM fill:#9cf,stroke:#333
```

## Health Check System

```mermaid
graph TD
    HC[Health Checker] --> N1[Node 1]
    HC --> N2[Node 2]
    HC --> N3[Node 3]
    
    N1 --> |Success| S1[Active]
    N1 --> |Failure| F1[Disabled]
    N2 --> |Success| S2[Active]
    N2 --> |Failure| F2[Disabled]
    N3 --> |Success| S3[Active]
    N3 --> |Failure| F3[Disabled]
    
    style HC fill:#f96,stroke:#333
    style S1 fill:#9f9,stroke:#333
    style S2 fill:#9f9,stroke:#333
    style S3 fill:#9f9,stroke:#333
    style F1 fill:#f66,stroke:#333
    style F2 fill:#f66,stroke:#333
    style F3 fill:#f66,stroke:#333
```

## Security Considerations

1. SSL/TLS Configuration
2. Access Control
3. Rate Limiting
4. DDoS Protection

## Troubleshooting

1. Check HAProxy status
```bash
docker-compose exec haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

2. View logs
```bash
docker-compose logs -f haproxy
```

3. Monitor statistics
```bash
curl http://localhost:8080/stats
```
