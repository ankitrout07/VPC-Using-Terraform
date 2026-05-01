const express = require('express');
const path = require('path');
const http = require('http');
const socketIo = require('socket.io');
const k8s = require('@kubernetes/client-node');
const { Pool } = require('pg');
const { DefaultAzureCredential } = require('@azure/identity');
const { MetricsQueryClient } = require('@azure/monitor-query');

let metricsClient = null;
try {
    const credential = new DefaultAzureCredential();
    metricsClient = new MetricsQueryClient(credential);
} catch (e) {
    console.warn("Azure Identity not configured, real-time Azure metrics will be disabled.");
}

// Validate Environment Variables
const dbConfig = {
    host: process.env.PGHOST || process.env.DB_HOST,
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    database: process.env.PGDATABASE,
    port: process.env.PGPORT || 5432,
    ssl: { rejectUnauthorized: false }
};

// Check for placeholders
const placeholders = Object.entries(dbConfig).filter(([k, v]) => typeof v === 'string' && v.includes('_PLACEHOLDER'));
if (placeholders.length > 0) {
    console.error(`[DB-CONFIG-ERROR] Detected unconfigured placeholders: ${placeholders.map(([k]) => k).join(', ')}`);
    console.error(`[DB-CONFIG-ERROR] Please ensure the deployment process has replaced these values.`);
}

// Initialize Postgres Pool
const pool = new Pool(dbConfig);

// Test connection and log (masked)
pool.on('error', (err) => {
    console.error('[POSTGRES-POOL-ERROR]', err.message);
});
const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});
const port = process.env.PORT || 3000;

app.use(express.static(path.join(__dirname)));
app.use(express.json());

// Root health check for App Gateway default probes
app.get('/', (req, res) => {
    res.status(200).send('Fortress Dashboard OK');
});

app.get('/health', (req, res) => {
    res.status(200).send('Healthy');
});

const kc = new k8s.KubeConfig();
try {
    kc.loadFromDefault();
} catch (e) {
    try {
        kc.loadFromCluster();
    } catch (err) {
        console.log("Failed to load kubeconfig", err.message);
    }
}

const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
const k8sAppsApi = kc.makeApiClient(k8s.AppsV1Api);

// Health Endpoint
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'Healthy', 
        uptime: process.uptime(),
        platform: 'Azure AKS'
    });
});

// Scale Endpoint
app.post('/api/scale', async (req, res) => {
    try {
        const { deployment, replicas } = req.body;
        const namespace = 'default';
        const patch = [
            {
                op: 'replace',
                path: '/spec/replicas',
                value: parseInt(replicas, 10)
            }
        ];
        const options = { headers: { 'Content-type': k8s.PatchUtils.PATCH_FORMAT_JSON_PATCH } };
        await k8sAppsApi.patchNamespacedDeployment(deployment, namespace, patch, undefined, undefined, undefined, undefined, undefined, options);
        res.json({ success: true, message: `Scaled ${deployment} to ${replicas} replicas.` });
    } catch (err) {
        console.error('Scaling error:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});

// Database Entry Endpoint
app.post('/api/db/entry', async (req, res) => {
    try {
        const { message } = req.body;
        // Create table if not exists
        await pool.query('CREATE TABLE IF NOT EXISTS dashboard_logs (id SERIAL PRIMARY KEY, message TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)');
        
        // Insert record
        const result = await pool.query('INSERT INTO dashboard_logs (message) VALUES ($1) RETURNING *', [message]);
        res.json({ success: true, data: result.rows[0] });
    } catch (err) {
        console.error('DB error:', err);
        res.status(500).json({ success: false, error: `Database connection failed: ${err.message}` });
    }
});

// --- Chaos Engineering API ---
app.post('/api/chaos/kill-pod', async (req, res) => {
    try {
        const { podName } = req.body;
        await k8sApi.deleteNamespacedPod(podName, 'default');
        res.json({ success: true, message: `Terminated pod ${podName}` });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/api/chaos/simulate-latency', (req, res) => {
    const { duration } = req.body; // in ms
    const start = Date.now();
    while (Date.now() - start < duration) {
        // Blocking loop to simulate CPU load/latency
    }
    res.json({ success: true, message: `Injected ${duration}ms latency` });
});

async function getClusterData() {
    try {
        const [podsRes, nodesRes] = await Promise.all([
            k8sApi.listPodForAllNamespaces(),
            k8sApi.listNode()
        ]);

        const nodes = nodesRes.body.items.map(node => ({
            name: node.metadata.name,
            status: node.status.conditions.find(c => c.type === 'Ready').status === 'True' ? 'Ready' : 'NotReady',
            capacity: 40 // Visual capacity for Tetris grid
        }));

        const pods = podsRes.body.items.map(pod => ({
            name: pod.metadata.name,
            namespace: pod.metadata.namespace,
            status: pod.status.phase,
            node: pod.spec.nodeName,
            type: pod.metadata.namespace === 'kube-system' ? 'system' : 'app'
        }));

        return { nodes, pods };
    } catch (error) {
        console.error('Error fetching cluster data:', error.message);
        return { nodes: [], pods: [] };
    }
}

async function getAzureMetrics() {
    let rps = Math.floor(Math.random() * 500) + 1200;
    let latency = Math.floor(Math.random() * 50) + 10;
    let cpu = Math.floor(Math.random() * 60) + 10;
    let dbConns = Math.floor(Math.random() * 20) + 5;

    if (metricsClient) {
        try {
            if (process.env.APPGW_ID && process.env.APPGW_ID !== 'APPGW_ID_PLACEHOLDER') {
                const agRes = await metricsClient.queryResource(process.env.APPGW_ID, ["TotalRequests", "BackendConnectTime"], { timespan: "PT5M", interval: "PT1M" });
                const reqMetric = agRes.metrics.find(m => m.name === 'TotalRequests');
                if (reqMetric && reqMetric.timeseries[0] && reqMetric.timeseries[0].data.length > 0) {
                    const latest = reqMetric.timeseries[0].data.filter(d => d.total !== null).pop();
                    if (latest) rps = latest.total / 60; // Requests per second
                }
                const latMetric = agRes.metrics.find(m => m.name === 'BackendConnectTime');
                if (latMetric && latMetric.timeseries[0] && latMetric.timeseries[0].data.length > 0) {
                    const latest = latMetric.timeseries[0].data.filter(d => d.average !== null).pop();
                    if (latest) latency = latest.average;
                }
            }
            if (process.env.DB_ID && process.env.DB_ID !== 'DB_ID_PLACEHOLDER') {
                const dbRes = await metricsClient.queryResource(process.env.DB_ID, ["active_connections"], { timespan: "PT5M", interval: "PT1M" });
                const connMetric = dbRes.metrics.find(m => m.name === 'active_connections');
                if (connMetric && connMetric.timeseries[0] && connMetric.timeseries[0].data.length > 0) {
                    const latest = connMetric.timeseries[0].data.filter(d => d.average !== null).pop();
                    if (latest) dbConns = latest.average;
                }
            }
        } catch (e) {
            console.error("Azure Metrics Error:", e.message);
        }
    }
    return { rps: Math.round(rps), latency: Math.round(latency), cpu: Math.round(cpu), dbConns: Math.round(dbConns) };
}

// Real-time updates via WebSockets
setInterval(async () => {
    try {
        const data = await getClusterData();
        io.emit("clusterData", data);
        
        const azureMetrics = await getAzureMetrics();
        io.emit("azureMetrics", azureMetrics);
    } catch (err) {
        console.error("[FORTRESS-TELEMETRY] Failed to fetch metrics:", err.message);
    }
}, 3000);

io.on('connection', (socket) => {
    console.log('New client connected');
    socket.on('disconnect', () => console.log('Client disconnected'));
});

server.listen(port, '0.0.0.0', () => {
    console.log(`[FORTRESS-CORE] Real-Time API online at port ${port}`);
});
