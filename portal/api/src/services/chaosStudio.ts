import { DefaultAzureCredential } from '@azure/identity';
import { ScenarioStatus } from '../types';

const CHAOS_API_VERSION = '2024-01-01';

export class ChaosStudioService {
  private credential: DefaultAzureCredential;
  private subscriptionId: string;
  private resourceGroupName: string;

  constructor() {
    this.credential = new DefaultAzureCredential();
    this.subscriptionId = process.env.AZURE_SUBSCRIPTION_ID || '';
    this.resourceGroupName = process.env.AZURE_RESOURCE_GROUP || '';

    if (!this.subscriptionId || !this.resourceGroupName) {
      console.warn(
        'AZURE_SUBSCRIPTION_ID and AZURE_RESOURCE_GROUP must be set for Chaos Studio operations'
      );
    }
  }

  private getExperimentUrl(experimentName: string): string {
    return `https://management.azure.com/subscriptions/${this.subscriptionId}/resourceGroups/${this.resourceGroupName}/providers/Microsoft.Chaos/experiments/${experimentName}`;
  }

  private async getToken(): Promise<string> {
    const tokenResponse = await this.credential.getToken(
      'https://management.azure.com/.default'
    );
    return tokenResponse.token;
  }

  async startExperiment(experimentName: string): Promise<{ success: boolean; message: string }> {
    const token = await this.getToken();
    const url = `${this.getExperimentUrl(experimentName)}/start?api-version=${CHAOS_API_VERSION}`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const body = await response.text();
      return { success: false, message: `Failed to start experiment: ${response.status} ${body}` };
    }

    return { success: true, message: 'Experiment started successfully' };
  }

  async stopExperiment(experimentName: string): Promise<{ success: boolean; message: string }> {
    const token = await this.getToken();
    const url = `${this.getExperimentUrl(experimentName)}/cancel?api-version=${CHAOS_API_VERSION}`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const body = await response.text();
      return { success: false, message: `Failed to cancel experiment: ${response.status} ${body}` };
    }

    return { success: true, message: 'Experiment cancelled' };
  }

  async getExperimentStatus(experimentName: string): Promise<ScenarioStatus> {
    const token = await this.getToken();
    const url = `${this.getExperimentUrl(experimentName)}/statuses?api-version=${CHAOS_API_VERSION}`;

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      return { name: experimentName, status: 'unknown', message: `HTTP ${response.status}` };
    }

    const data = (await response.json()) as {
      value?: Array<{ properties: { status: string; startTime?: string } }>;
    };
    const latest = data.value?.[0]?.properties;

    if (!latest) {
      return { name: experimentName, status: 'idle' };
    }

    const statusMap: Record<string, ScenarioStatus['status']> = {
      Running: 'running',
      Success: 'success',
      Failed: 'failed',
      Cancelled: 'cancelled',
    };

    return {
      name: experimentName,
      status: statusMap[latest.status] || 'unknown',
      startedAt: latest.startTime,
      message: latest.status,
    };
  }
}
