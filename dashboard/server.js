const express = require('express');
const path = require('path');
const http = require('http');
const socketIo = require('socket.io');
const k8s = require('@kubernetes/client-node');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});
const port = 80;

app.use(express.static(path.join(__dirname)));

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

// Health Endpoint
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'Healthy', 
        uptime: process.uptime(),
        platform: 'Azure AKS'
    });
});

async function getPods() {
    try {
        const res = await k8sApi.listNamespacedPod("default");
        return res.body.items.map(pod => ({
            name: pod.metadata.name,
            status: pod.status.phase,
            node: pod.spec.nodeName,
            startTime: pod.status.startTime,
            ip: pod.status.podIP
        }));
    } catch (error) {
        console.error('Error fetching pods:', error.message);
        return [];
    }
}

// Real-time updates via WebSockets
setInterval(async () => {
    const pods = await getPods();
    io.emit("pods", pods);
}, 2000);

io.on('connection', (socket) => {
    console.log('New client connected');
    socket.on('disconnect', () => console.log('Client disconnected'));
});

server.listen(port, () => {
  console.log(`Fortress Real-Time API listening on port ${port}`);
});
