import { Router, Request, Response } from 'express';
import { scenarios } from '../scenarios';
import { ChaosStudioService } from '../services/chaosStudio';
import { KubernetesService } from '../services/kubernetes';
import { logActivity } from '../services/activityStore';
import { ScenarioStatus } from '../types';

const router = Router();
const chaosService = new ChaosStudioService();
const k8sService = new KubernetesService();

// GET /api/scenarios — list all scenarios with metadata
router.get('/', (_req: Request, res: Response) => {
  res.json(scenarios);
});

// GET /api/scenarios/:name/status — get scenario status
router.get('/:name/status', async (req: Request, res: Response) => {
  const scenario = scenarios.find((s) => s.name === req.params.name);
  if (!scenario) {
    res.status(404).json({ error: `Scenario not found: ${req.params.name}` });
    return;
  }

  try {
    if (scenario.type === 'chaos' && scenario.experimentName) {
      const status = await chaosService.getExperimentStatus(scenario.experimentName);
      // Enrich with estimated end time when running
      if (status.status === 'running' && status.startedAt && scenario.durationMinutes) {
        const end = new Date(new Date(status.startedAt).getTime() + scenario.durationMinutes * 60 * 1000);
        status.estimatedEndTime = end.toISOString();
      }
      res.json(status);
      return;
    }

    // kubectl scenarios don't have a status API — derive from pod state
    const pods = await k8sService.getPods();
    const targetPods = pods.filter(
      (p) => p.name.startsWith(scenario.target) || p.name.includes(scenario.target)
    );

    const hasBrokenPods = targetPods.some(
      (p) =>
        p.status !== 'Running' || p.restarts > 3 || p.ready.split('/')[0] !== p.ready.split('/')[1]
    );

    const status: ScenarioStatus = {
      name: scenario.name,
      status: hasBrokenPods ? 'broken' : 'idle',
    };
    res.json(status);
  } catch (err) {
    console.error(`Error getting status for ${scenario.name}:`, err);
    res.json({ name: scenario.name, status: 'unknown', message: 'Failed to get status' });
  }
});

// POST /api/scenarios/:name/start — inject failure
router.post('/:name/start', async (req: Request, res: Response) => {
  const scenario = scenarios.find((s) => s.name === req.params.name);
  if (!scenario) {
    res.status(404).json({ error: `Scenario not found: ${req.params.name}` });
    return;
  }

  try {
    if (scenario.type === 'chaos' && scenario.experimentName) {
      const result = await chaosService.startExperiment(scenario.experimentName);
      await logActivity(scenario.displayName, result.success ? 'Chaos experiment started' : `Failed to start: ${result.message}`, result.success ? 'info' : 'error');
      res.json(result);
      return;
    }

    if (scenario.type === 'kubectl' && scenario.scenarioFile) {
      const result = await k8sService.applyScenarioFile(scenario.scenarioFile);
      await logActivity(scenario.displayName, result.success ? 'kubectl scenario applied' : `Failed to apply: ${result.message}`, result.success ? 'info' : 'error');
      res.json(result);
      return;
    }

    res.status(400).json({ error: 'Scenario not actionable' });
  } catch (err) {
    console.error(`Error starting ${scenario.name}:`, err);
    await logActivity(scenario.displayName, `Error starting: ${err instanceof Error ? err.message : String(err)}`, 'error');
    res.json({ success: false, message: `Failed to start: ${err instanceof Error ? err.message : String(err)}` });
  }
});

// POST /api/scenarios/:name/stop — cancel/fix
router.post('/:name/stop', async (req: Request, res: Response) => {
  const scenario = scenarios.find((s) => s.name === req.params.name);
  if (!scenario) {
    res.status(404).json({ error: `Scenario not found: ${req.params.name}` });
    return;
  }

  try {
    if (scenario.type === 'chaos' && scenario.experimentName) {
      const result = await chaosService.stopExperiment(scenario.experimentName);
      await logActivity(scenario.displayName, result.success ? 'Chaos experiment stopped' : `Failed to stop: ${result.message}`, result.success ? 'warning' : 'error');
      res.json(result);
      return;
    }

    if (scenario.type === 'kubectl' && scenario.fixCommand) {
      const result = await k8sService.fixScenario(scenario.fixCommand);
      await logActivity(scenario.displayName, result.success ? 'kubectl fix applied' : `Failed to fix: ${result.message}`, result.success ? 'success' : 'error');
      res.json(result);
      return;
    }

    res.status(400).json({ error: 'Scenario not actionable' });
  } catch (err) {
    console.error(`Error stopping ${scenario.name}:`, err);
    await logActivity(scenario.displayName, `Error stopping: ${err instanceof Error ? err.message : String(err)}`, 'error');
    res.json({ success: false, message: `Failed to stop: ${err instanceof Error ? err.message : String(err)}` });
  }
});

// POST /api/scenarios/fix-all — global recovery
router.post('/fix-all', async (_req: Request, res: Response) => {
  try {
    // Cancel all running Chaos experiments
    const chaosResults: Array<{ name: string; result: { success: boolean; message: string } }> = [];
    for (const s of scenarios.filter((s) => s.type === 'chaos' && s.experimentName)) {
      try {
        const result = await chaosService.stopExperiment(s.experimentName!);
        chaosResults.push({ name: s.name, result });
      } catch (err) {
        chaosResults.push({ name: s.name, result: { success: false, message: String(err) } });
      }
    }

    // Fix all kubectl scenarios
    const k8sResult = await k8sService.fixAll();

    await logActivity('Fix All', 'All scenarios reverted to baseline', 'success');

    res.json({
      chaos: chaosResults,
      kubernetes: k8sResult,
      message: 'Fix All complete — baseline restored',
    });
  } catch (err) {
    console.error('Error in fix-all:', err);
    res.status(500).json({ message: `Fix All failed: ${err instanceof Error ? err.message : String(err)}` });
  }
});

export default router;
