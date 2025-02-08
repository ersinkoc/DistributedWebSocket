const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { body, validationResult } = require('express-validator');
const sqlite3 = require('sqlite3').verbose();
const winston = require('winston');
require('dotenv').config();

// Configure logger
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'error.log', level: 'error' }),
        new winston.transports.File({ filename: 'combined.log' })
    ]
});

// Initialize Express app
const app = express();
app.use(express.json());
app.use(cors());
app.use(helmet());

// Initialize SQLite database
const dbPath = process.env.DB_PATH || '/data/ws.db';
const db = new sqlite3.Database(dbPath, (err) => {
    if (err) {
        logger.error('Database connection failed:', err);
        process.exit(1);
    }
    logger.info('Connected to SQLite database');
    
    // Create tables if they don't exist
    db.run(`CREATE TABLE IF NOT EXISTS nodes (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);
    
    db.run(`CREATE TABLE IF NOT EXISTS channels (
        id TEXT PRIMARY KEY,
        node_id TEXT,
        name TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (node_id) REFERENCES nodes(id)
    )`);
});

// Middleware for API key validation
const validateApiKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'];
    if (!apiKey || apiKey !== process.env.API_KEY) {
        return res.status(401).json({ error: 'Invalid API key' });
    }
    next();
};

// Node registration endpoint
app.post('/nodes', 
    validateApiKey,
    [
        body('id').isString().notEmpty(),
        body('url').isURL()
    ],
    async (req, res) => {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const { id, url } = req.body;
        
        db.run('INSERT OR REPLACE INTO nodes (id, url) VALUES (?, ?)',
            [id, url],
            function(err) {
                if (err) {
                    logger.error('Error registering node:', err);
                    return res.status(500).json({ error: 'Failed to register node' });
                }
                logger.info(`Node registered: ${id}`);
                res.status(200).json({ id, url });
            }
        );
    }
);

// Channel registration endpoint
app.post('/channels',
    validateApiKey,
    [
        body('nodeId').isString().notEmpty(),
        body('name').isString().notEmpty()
    ],
    async (req, res) => {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const { nodeId, name } = req.body;
        const channelId = `${nodeId}-${name}`;
        
        db.run('INSERT OR REPLACE INTO channels (id, node_id, name) VALUES (?, ?, ?)',
            [channelId, nodeId, name],
            function(err) {
                if (err) {
                    logger.error('Error registering channel:', err);
                    return res.status(500).json({ error: 'Failed to register channel' });
                }
                logger.info(`Channel registered: ${channelId}`);
                res.status(200).json({ id: channelId, nodeId, name });
            }
        );
    }
);

// Get all active nodes
app.get('/nodes',
    validateApiKey,
    (req, res) => {
        db.all('SELECT * FROM nodes WHERE status = ?', ['active'],
            (err, rows) => {
                if (err) {
                    logger.error('Error fetching nodes:', err);
                    return res.status(500).json({ error: 'Failed to fetch nodes' });
                }
                res.json(rows);
            }
        );
    }
);

// Get all channels for a node
app.get('/nodes/:nodeId/channels',
    validateApiKey,
    (req, res) => {
        const { nodeId } = req.params;
        
        db.all('SELECT * FROM channels WHERE node_id = ? AND status = ?',
            [nodeId, 'active'],
            (err, rows) => {
                if (err) {
                    logger.error('Error fetching channels:', err);
                    return res.status(500).json({ error: 'Failed to fetch channels' });
                }
                res.json(rows);
            }
        );
    }
);

// Node heartbeat endpoint
app.post('/nodes/:nodeId/heartbeat',
    validateApiKey,
    (req, res) => {
        const { nodeId } = req.params;
        
        db.run('UPDATE nodes SET last_seen = CURRENT_TIMESTAMP WHERE id = ?',
            [nodeId],
            function(err) {
                if (err) {
                    logger.error('Error updating heartbeat:', err);
                    return res.status(500).json({ error: 'Failed to update heartbeat' });
                }
                if (this.changes === 0) {
                    return res.status(404).json({ error: 'Node not found' });
                }
                res.status(200).json({ status: 'ok' });
            }
        );
    }
);

// Start server
const port = process.env.PORT || 8000;
app.listen(port, () => {
    logger.info(`Server running on port ${port}`);
});
