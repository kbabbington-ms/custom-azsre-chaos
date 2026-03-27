import express from 'express';
import cors from 'cors';
import scenarioRoutes from './routes/scenarios';
import clusterRoutes from './routes/cluster';
import activityRoutes from './routes/activities';

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Health probe
app.get('/api/health', (_req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});

// Routes
app.use('/api/scenarios', scenarioRoutes);
app.use('/api/cluster', clusterRoutes);
app.use('/api/activities', activityRoutes);

app.listen(PORT, () => {
  console.log(`Chaos Portal API listening on port ${PORT}`);
  console.log(`  Subscription: ${process.env.AZURE_SUBSCRIPTION_ID || '(not set)'}`);
  console.log(`  Resource Group: ${process.env.AZURE_RESOURCE_GROUP || '(not set)'}`);
  console.log(`  Workload Name: ${process.env.WORKLOAD_NAME || 'srelab'}`);
});
