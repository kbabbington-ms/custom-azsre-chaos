import { Router, Request, Response } from 'express';
import { getActivities, logActivity } from '../services/activityStore';
import { ActivityLevel } from '../types';

const router = Router();

// GET /api/activities?limit=200
router.get('/', async (req: Request, res: Response) => {
  const limit = Math.min(Number(req.query.limit) || 200, 1000);
  const entries = await getActivities(limit);
  res.json(entries);
});

// POST /api/activities — log from frontend
router.post('/', async (req: Request, res: Response) => {
  const { scenario, message, level } = req.body as {
    scenario?: string;
    message?: string;
    level?: ActivityLevel;
  };

  if (!scenario || !message) {
    res.status(400).json({ error: 'scenario and message are required' });
    return;
  }

  const entry = await logActivity(scenario, message, level || 'info');
  res.status(201).json(entry);
});

export default router;
