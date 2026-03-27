import * as k8s from '@kubernetes/client-node';
import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';
import { PodInfo } from '../types';

const PETS_NAMESPACE = 'pets';

export class KubernetesService {
  private coreApi: k8s.CoreV1Api;
  private appsApi: k8s.AppsV1Api;
  private networkingApi: k8s.NetworkingV1Api;
  private kc: k8s.KubeConfig;

  constructor() {
    this.kc = new k8s.KubeConfig();
    this.kc.loadFromCluster();
    this.coreApi = this.kc.makeApiClient(k8s.CoreV1Api);
    this.appsApi = this.kc.makeApiClient(k8s.AppsV1Api);
    this.networkingApi = this.kc.makeApiClient(k8s.NetworkingV1Api);
  }

  async getPods(): Promise<PodInfo[]> {
    const { body } = await this.coreApi.listNamespacedPod(PETS_NAMESPACE);
    const now = Date.now();

    return body.items.map((pod: k8s.V1Pod) => {
      const containerStatuses = pod.status?.containerStatuses || [];
      const readyCount = containerStatuses.filter((c: k8s.V1ContainerStatus) => c.ready).length;
      const totalCount = containerStatuses.length || pod.spec?.containers?.length || 0;
      const restarts = containerStatuses.reduce((sum: number, c: k8s.V1ContainerStatus) => sum + (c.restartCount || 0), 0);
      const createdAt = pod.metadata?.creationTimestamp
        ? new Date(pod.metadata.creationTimestamp).getTime()
        : now;
      const ageMs = now - createdAt;
      const ageMinutes = Math.floor(ageMs / 60000);
      const age =
        ageMinutes < 60
          ? `${ageMinutes}m`
          : ageMinutes < 1440
            ? `${Math.floor(ageMinutes / 60)}h`
            : `${Math.floor(ageMinutes / 1440)}d`;

      return {
        name: pod.metadata?.name || 'unknown',
        namespace: PETS_NAMESPACE,
        status: pod.status?.phase || 'Unknown',
        ready: `${readyCount}/${totalCount}`,
        restarts,
        age,
        node: pod.spec?.nodeName || '',
      };
    });
  }

  async applyScenarioFile(scenarioFile: string): Promise<{ success: boolean; message: string }> {
    const scenarioPath = path.resolve('/app/scenarios', scenarioFile);
    if (!fs.existsSync(scenarioPath)) {
      return { success: false, message: `Scenario file not found: ${scenarioFile}` };
    }

    const content = fs.readFileSync(scenarioPath, 'utf-8');
    const docs = yaml.loadAll(content) as k8s.KubernetesObject[];

    for (const doc of docs) {
      if (!doc || !doc.kind) continue;
      await this.applyResource(doc);
    }

    return { success: true, message: `Applied ${scenarioFile}` };
  }

  async fixScenario(fixCommand: string): Promise<{ success: boolean; message: string }> {
    if (fixCommand === 'apply-baseline') {
      return this.applyBaselineManifest();
    }

    if (fixCommand.startsWith('delete-deployment:')) {
      const deploymentName = fixCommand.split(':')[1];
      return this.deleteDeployment(deploymentName);
    }

    return { success: false, message: `Unknown fix command: ${fixCommand}` };
  }

  async applyBaselineManifest(): Promise<{ success: boolean; message: string }> {
    const baselinePath = path.resolve('/app/scenarios', 'application.yaml');
    if (!fs.existsSync(baselinePath)) {
      return { success: false, message: 'Baseline application.yaml not found' };
    }

    const content = fs.readFileSync(baselinePath, 'utf-8');
    const docs = yaml.loadAll(content) as k8s.KubernetesObject[];

    let applied = 0;
    for (const doc of docs) {
      if (!doc || !doc.kind) continue;
      await this.applyResource(doc);
      applied++;
    }

    return { success: true, message: `Applied baseline (${applied} resources)` };
  }

  async fixAll(): Promise<{ success: boolean; message: string }> {
    const results: string[] = [];

    // Delete extra breakable deployments
    for (const name of ['resource-hog', 'misconfigured-service']) {
      try {
        await this.appsApi.deleteNamespacedDeployment(name, PETS_NAMESPACE);
        results.push(`Deleted ${name}`);
      } catch {
        // May not exist, that's fine
      }
    }

    // Apply baseline to restore healthy state
    const baseline = await this.applyBaselineManifest();
    if (baseline.success) {
      results.push(baseline.message);
    }

    return { success: true, message: results.join('; ') };
  }

  private async deleteDeployment(
    name: string
  ): Promise<{ success: boolean; message: string }> {
    try {
      await this.appsApi.deleteNamespacedDeployment(name, PETS_NAMESPACE);
      return { success: true, message: `Deleted deployment ${name}` };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      return { success: false, message: `Failed to delete ${name}: ${message}` };
    }
  }

  private async applyResource(resource: k8s.KubernetesObject): Promise<void> {
    const name = resource.metadata?.name;
    const namespace = resource.metadata?.namespace || PETS_NAMESPACE;
    if (!name) return;

    switch (resource.kind) {
      case 'Namespace':
        try {
          await this.coreApi.readNamespace(name);
        } catch {
          await this.coreApi.createNamespace(resource as k8s.V1Namespace);
        }
        break;

      case 'Deployment':
        try {
          await this.appsApi.readNamespacedDeployment(name, namespace);
          await this.appsApi.replaceNamespacedDeployment(
            name, namespace, resource as k8s.V1Deployment
          );
        } catch {
          await this.appsApi.createNamespacedDeployment(
            namespace, resource as k8s.V1Deployment
          );
        }
        break;

      case 'Service':
        try {
          await this.coreApi.readNamespacedService(name, namespace);
          await this.coreApi.replaceNamespacedService(
            name, namespace, resource as k8s.V1Service
          );
        } catch {
          await this.coreApi.createNamespacedService(
            namespace, resource as k8s.V1Service
          );
        }
        break;

      case 'ConfigMap':
        try {
          await this.coreApi.readNamespacedConfigMap(name, namespace);
          await this.coreApi.replaceNamespacedConfigMap(
            name, namespace, resource as k8s.V1ConfigMap
          );
        } catch {
          await this.coreApi.createNamespacedConfigMap(
            namespace, resource as k8s.V1ConfigMap
          );
        }
        break;

      case 'Secret':
        try {
          await this.coreApi.readNamespacedSecret(name, namespace);
          await this.coreApi.replaceNamespacedSecret(
            name, namespace, resource as k8s.V1Secret
          );
        } catch {
          await this.coreApi.createNamespacedSecret(
            namespace, resource as k8s.V1Secret
          );
        }
        break;

      case 'StatefulSet':
        try {
          await this.appsApi.readNamespacedStatefulSet(name, namespace);
          await this.appsApi.replaceNamespacedStatefulSet(
            name, namespace, resource as k8s.V1StatefulSet
          );
        } catch {
          await this.appsApi.createNamespacedStatefulSet(
            namespace, resource as k8s.V1StatefulSet
          );
        }
        break;

      case 'NetworkPolicy':
        try {
          await this.networkingApi.readNamespacedNetworkPolicy(name, namespace);
          await this.networkingApi.replaceNamespacedNetworkPolicy(
            name, namespace, resource as k8s.V1NetworkPolicy
          );
        } catch {
          await this.networkingApi.createNamespacedNetworkPolicy(
            namespace, resource as k8s.V1NetworkPolicy
          );
        }
        break;

      default:
        console.log(`Skipping unsupported resource kind: ${resource.kind}`);
    }
  }
}
