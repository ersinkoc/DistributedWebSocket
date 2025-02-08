require('dotenv').config();
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const fetch = require('node-fetch');
const winston = require('winston');

// Configuration
const NODE_ID = process.env.NODE_ID || uuidv4();
const PORT = process.env.PORT || 8080;
const WS_UPDATES_URL = process.env.WS_UPDATES_URL || 'http://wsupdates.example.com';
const UPDATE_INTERVAL = process.env.UPDATE_INTERVAL || 30000;

// Logger setup
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.json(),
    transports: [
        new winston.transports.File({ filename: 'error.log', level: 'error' }),
        new winston.transports.File({ filename: 'combined.log' }),
        new winston.transports.Console({
            format: winston.format.simple()
        })
    ]
});

// Initialize application
const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Store connected nodes and clients
const connectedNodes = new Map();
const connectedClients = new Map();
const channelSubscriptions = new Map();

// Middleware for JSON parsing
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
    const metrics = getNodeMetrics();
    res.json(metrics);
});

// Detailed metrics endpoint
app.get('/metrics', (req, res) => {
    const apiKey = req.headers['x-api-key'];
    if (!apiKey || apiKey !== process.env.API_KEY) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    
    const metrics = getNodeMetrics();
    res.json(metrics);
});

// Get node metrics
function getNodeMetrics() {
    // Channel metrics
    const channelMetrics = {};
    for (const [channel, subscribers] of channelSubscriptions.entries()) {
        channelMetrics[channel] = {
            subscriberCount: subscribers.size,
            subscribers: Array.from(subscribers)
        };
    }

    return {
        nodeId: NODE_ID,
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
        metrics: {
            clients: {
                total: connectedClients.size,
                channels: channelMetrics
            },
            system: {
                memory: process.memoryUsage(),
                cpu: process.cpuUsage()
            },
            network: {
                connectedNodes: Array.from(connectedNodes.keys())
            }
        }
    };
}

// Protected broadcast endpoint
app.post('/broadcast', async (req, res) => {
    const { channel, message, apiKey, origin = null } = req.body;
    
    if (!apiKey || apiKey !== process.env.API_KEY) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!channel || !message) {
        return res.status(400).json({ error: 'Channel and message are required' });
    }

    try {
        // If this is an original broadcast (not forwarded), send to other nodes first
        if (!origin) {
            await forwardMessageToNodes(channel, message);
        }

        // Broadcast to local subscribers
        const subscribers = channelSubscriptions.get(channel);
        if (!subscribers || subscribers.size === 0) {
            return res.json({ 
                success: true, 
                nodeId: NODE_ID,
                subscribers: 0,
                message: 'No subscribers for this channel'
            });
        }

        const messagePayload = {
            type: 'broadcast',
            channel,
            message,
            timestamp: new Date().toISOString(),
            nodeId: NODE_ID
        };

        const messageStr = JSON.stringify(messagePayload);
        let deliveredCount = 0;

        subscribers.forEach(clientId => {
            const client = connectedClients.get(clientId);
            if (client?.readyState === WebSocket.OPEN) {
                client.send(messageStr);
                deliveredCount++;
            }
        });

        logger.info(`Broadcast message delivered to ${deliveredCount} clients on channel ${channel}`);
        
        res.json({ 
            success: true, 
            nodeId: NODE_ID,
            delivered: deliveredCount,
            total: subscribers.size
        });
    } catch (error) {
        logger.error('Error in broadcast:', error);
        res.status(500).json({ 
            error: 'Broadcast failed', 
            message: error.message 
        });
    }
});

// Forward message to other nodes
async function forwardMessageToNodes(channel, message) {
    const forwardPromises = [];
    
    for (const [nodeId, nodeInfo] of connectedNodes) {
        if (nodeId === NODE_ID) continue;

        const promise = fetch(`${nodeInfo.url}/broadcast`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                channel,
                message,
                apiKey: process.env.API_KEY,
                origin: NODE_ID // Mark as forwarded message
            })
        }).catch(error => {
            logger.error(`Failed to forward message to node ${nodeId}:`, error);
            return null;
        });

        forwardPromises.push(promise);
    }

    // Wait for all forwards to complete
    const results = await Promise.allSettled(forwardPromises);
    const successfulForwards = results.filter(r => r.status === 'fulfilled' && r.value).length;
    
    logger.info(`Message forwarded to ${successfulForwards}/${connectedNodes.size - 1} nodes`);
    
    return successfulForwards;
}

// WebSocket connection handler
wss.on('connection', (ws, req) => {
    const clientId = uuidv4();
    connectedClients.set(clientId, ws);

    logger.info(`Client connected: ${clientId}`);

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            
            if (data.type === 'subscribe') {
                handleSubscription(clientId, ws, data.channel);
            } else {
                // Ignore any other message types from clients
                logger.warn(`Ignored message of type ${data.type} from client ${clientId}`);
            }
        } catch (error) {
            logger.error('Error processing message:', error);
        }
    });

    // Send initial connection acknowledgment
    ws.send(JSON.stringify({
        type: 'connected',
        clientId,
        nodeId: NODE_ID,
        timestamp: new Date().toISOString()
    }));

    ws.on('close', () => {
        handleClientDisconnection(clientId);
    });
});

// Handle channel subscription
function handleSubscription(clientId, ws, channel) {
    if (!channelSubscriptions.has(channel)) {
        channelSubscriptions.set(channel, new Set());
    }
    channelSubscriptions.get(channel).add(clientId);
    logger.info(`Client ${clientId} subscribed to channel ${channel}`);
}

// Handle client disconnection
function handleClientDisconnection(clientId) {
    connectedClients.delete(clientId);
    
    // Remove from all channel subscriptions
    for (const [channel, subscribers] of channelSubscriptions.entries()) {
        subscribers.delete(clientId);
        if (subscribers.size === 0) {
            channelSubscriptions.delete(channel);
        }
    }
    
    logger.info(`Client disconnected: ${clientId}`);
}

// Update node list from WSUpdates service
async function updateNodeList() {
    try {
        const response = await fetch(`${WS_UPDATES_URL}/nodes`);
        const nodes = await response.json();
        
        // Update connected nodes
        connectedNodes.clear();
        nodes.forEach(node => {
            if (node.id !== NODE_ID) {
                connectedNodes.set(node.id, node);
            }
        });

        // Announce presence to other nodes
        announcePresence();
    } catch (error) {
        logger.error('Error updating node list:', error);
    }
}

// Announce presence to other nodes
async function announcePresence() {
    try {
        await fetch(`${WS_UPDATES_URL}/announce`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                id: NODE_ID,
                url: `http://localhost:${PORT}`,
                status: 'active'
            })
        });
    } catch (error) {
        logger.error('Error announcing presence:', error);
    }
}

// Start server
server.listen(PORT, () => {
    logger.info(`WSNode server started on port ${PORT} with ID: ${NODE_ID}`);
    
    // Initial node list update
    updateNodeList();
    
    // Schedule periodic updates
    setInterval(updateNodeList, UPDATE_INTERVAL);
});
