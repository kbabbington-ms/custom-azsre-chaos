import { Router, Request, Response } from 'express';
import { KubernetesService } from '../services/kubernetes';

const router = Router();
const k8sService = new KubernetesService();

// GET /api/cluster/pods — pod status from pets namespace
router.get('/pods', async (_req: Request, res: Response) => {
  const pods = await k8sService.getPods();
  res.json(pods);
});

export default router;
