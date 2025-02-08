<?php

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Slim\Factory\AppFactory;
use PDO;
use GuzzleHttp\Client;

require __DIR__ . '/../vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

// Initialize SQLite database
$db = new PDO('sqlite:' . $_ENV['DB_PATH']);
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// Create tables if they don't exist
$db->exec('
    CREATE TABLE IF NOT EXISTS nodes (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        status TEXT NOT NULL,
        last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
        metrics TEXT
    );
    
    CREATE TABLE IF NOT EXISTS channels (
        name TEXT PRIMARY KEY,
        allowed_nodes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
');

// Create Slim app
$app = AppFactory::create();

// Middleware for API key authentication
$app->add(function (Request $request, $handler) {
    $route = $request->getUri()->getPath();
    
    // Skip authentication for health check
    if ($route === '/health') {
        return $handler->handle($request);
    }
    
    $apiKey = $request->getHeaderLine('X-API-Key');
    if ($apiKey !== $_ENV['API_KEY']) {
        $response = new \Slim\Psr7\Response();
        return $response
            ->withStatus(401)
            ->withHeader('Content-Type', 'application/json')
            ->write(json_encode(['error' => 'Unauthorized']));
    }
    
    return $handler->handle($request);
});

// Health check endpoint
$app->get('/health', function (Request $request, Response $response) {
    $data = [
        'status' => 'healthy',
        'timestamp' => date('c')
    ];
    $response->getBody()->write(json_encode($data));
    return $response->withHeader('Content-Type', 'application/json');
});

// Get all active nodes
$app->get('/nodes', function (Request $request, Response $response) use ($db) {
    $stmt = $db->query('
        SELECT id, url, status, last_seen 
        FROM nodes 
        WHERE status = "active" 
        AND datetime(last_seen) > datetime("now", "-5 minutes")
    ');
    $nodes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $response->getBody()->write(json_encode($nodes));
    return $response->withHeader('Content-Type', 'application/json');
});

// Announce node presence
$app->post('/announce', function (Request $request, Response $response) use ($db) {
    $data = json_decode($request->getBody()->getContents(), true);
    
    if (!isset($data['id']) || !isset($data['url']) || !isset($data['status'])) {
        return $response
            ->withStatus(400)
            ->withHeader('Content-Type', 'application/json')
            ->write(json_encode(['error' => 'Missing required fields']));
    }
    
    $stmt = $db->prepare('
        INSERT OR REPLACE INTO nodes (id, url, status, last_seen)
        VALUES (:id, :url, :status, CURRENT_TIMESTAMP)
    ');
    
    $stmt->execute([
        ':id' => $data['id'],
        ':url' => $data['url'],
        ':status' => $data['status']
    ]);
    
    return $response
        ->withStatus(200)
        ->withHeader('Content-Type', 'application/json')
        ->write(json_encode(['success' => true]));
});

// Get allowed channels for a node
$app->get('/channels/{nodeId}', function (Request $request, Response $response, array $args) use ($db) {
    $nodeId = $args['nodeId'];
    
    $stmt = $db->prepare('
        SELECT name 
        FROM channels 
        WHERE allowed_nodes LIKE :nodeId 
        OR allowed_nodes = "*"
    ');
    
    $stmt->execute([':nodeId' => "%$nodeId%"]);
    $channels = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    $response->getBody()->write(json_encode($channels));
    return $response->withHeader('Content-Type', 'application/json');
});

// Add or update channel
$app->post('/channels', function (Request $request, Response $response) use ($db) {
    $data = json_decode($request->getBody()->getContents(), true);
    
    if (!isset($data['name']) || !isset($data['allowed_nodes'])) {
        return $response
            ->withStatus(400)
            ->withHeader('Content-Type', 'application/json')
            ->write(json_encode(['error' => 'Missing required fields']));
    }
    
    $stmt = $db->prepare('
        INSERT OR REPLACE INTO channels (name, allowed_nodes)
        VALUES (:name, :allowed_nodes)
    ');
    
    $stmt->execute([
        ':name' => $data['name'],
        ':allowed_nodes' => is_array($data['allowed_nodes']) 
            ? implode(',', $data['allowed_nodes']) 
            : $data['allowed_nodes']
    ]);
    
    return $response
        ->withStatus(200)
        ->withHeader('Content-Type', 'application/json')
        ->write(json_encode(['success' => true]));
});

// Get cluster-wide metrics
$app->get('/cluster/metrics', function (Request $request, Response $response) use ($db) {
    // Get all active nodes
    $stmt = $db->query('
        SELECT id, url, status, last_seen 
        FROM nodes 
        WHERE status = "active" 
        AND datetime(last_seen) > datetime("now", "-5 minutes")
    ');
    $nodes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Collect metrics from all nodes
    $clusterMetrics = [
        'timestamp' => date('c'),
        'totalNodes' => count($nodes),
        'nodes' => [],
        'summary' => [
            'totalClients' => 0,
            'channels' => []
        ]
    ];
    
    foreach ($nodes as $node) {
        try {
            $client = new Client();
            $metricsResponse = $client->get($node['url'] . '/metrics', [
                'headers' => [
                    'X-API-Key' => $_ENV['API_KEY']
                ],
                'timeout' => 5
            ]);
            
            $nodeMetrics = json_decode($metricsResponse->getBody(), true);
            $clusterMetrics['nodes'][$node['id']] = $nodeMetrics;
            
            // Update summary
            $clusterMetrics['summary']['totalClients'] += $nodeMetrics['metrics']['clients']['total'];
            
            // Aggregate channel statistics
            foreach ($nodeMetrics['metrics']['clients']['channels'] as $channel => $stats) {
                if (!isset($clusterMetrics['summary']['channels'][$channel])) {
                    $clusterMetrics['summary']['channels'][$channel] = [
                        'totalSubscribers' => 0,
                        'nodesServing' => 0
                    ];
                }
                $clusterMetrics['summary']['channels'][$channel]['totalSubscribers'] += $stats['subscriberCount'];
                $clusterMetrics['summary']['channels'][$channel]['nodesServing']++;
            }
        } catch (\Exception $e) {
            $clusterMetrics['nodes'][$node['id']] = [
                'error' => $e->getMessage(),
                'status' => 'error'
            ];
        }
    }
    
    $response->getBody()->write(json_encode($clusterMetrics));
    return $response->withHeader('Content-Type', 'application/json');
});

// Store node metrics
$app->post('/metrics/{nodeId}', function (Request $request, Response $response, array $args) use ($db) {
    $nodeId = $args['nodeId'];
    $metrics = json_decode($request->getBody()->getContents(), true);
    
    // Store metrics in database (optional)
    $stmt = $db->prepare('
        UPDATE nodes 
        SET metrics = :metrics,
            last_seen = CURRENT_TIMESTAMP
        WHERE id = :id
    ');
    
    $stmt->execute([
        ':id' => $nodeId,
        ':metrics' => json_encode($metrics)
    ]);
    
    return $response
        ->withStatus(200)
        ->withHeader('Content-Type', 'application/json')
        ->write(json_encode(['success' => true]));
});

// Run the application
$app->run();
