/**
 * Simulates a real-time 4-channel EEG data stream for testing and development.
 * Channels: AF7, AF8, TP9, TP10 (Muse 2/S electrode layout).
 * Provides three simulation modes: NORMAL, MODERATE, and SEIZURE.
 *
 * This is a temporary service until actual hardware (EEG wearable) is integrated.
 */
import {
  SAMPLE_INTERVAL_MS, SERVICE_BUFFER_SIZE,
  EEG_CHANNEL_COUNT
} from '../constants/AppConstants';

export interface EEGDataPoint {
  timestamp: number;
  channels: number[]; // 4 channels in µV: [AF7, AF8, TP9, TP10]
}

export enum EEGSimulationMode {
  NORMAL = 'NORMAL',
  MODERATE = 'MODERATE',
  SEIZURE = 'SEIZURE'
}

// Phase offsets per channel to simulate spatial separation between electrodes.
// AF7/AF8 are frontal (closer together), TP9/TP10 are temporal (further apart).
const CHANNEL_PHASE_OFFSETS: number[] = [0.0, 0.3, 0.7, 1.0];
const CHANNEL_AMPLITUDE_SCALE: number[] = [1.0, 0.95, 1.1, 1.05];

export class MockEEGService {
  private simulationMode: EEGSimulationMode = EEGSimulationMode.SEIZURE;
  private isRunning: boolean = false;
  private streamInterval: number | null = null;
  private dataBuffer: EEGDataPoint[] = [];

  private onDataReceivedCallback: ((data: EEGDataPoint) => void) | null = null;
  private onModeChangedCallback: ((mode: EEGSimulationMode) => void) | null = null;

  constructor() {
    console.info('[MockEEGService] Initialized (4-channel)');
  }

  public onDataReceived(callback: (data: EEGDataPoint) => void): void {
    this.onDataReceivedCallback = callback;
  }

  public onModeChanged(callback: (mode: EEGSimulationMode) => void): void {
    this.onModeChangedCallback = callback;
  }

  public startStream(): void {
    if (this.isRunning) {
      console.warn('[MockEEGService] Stream already running');
      return;
    }

    this.isRunning = true;
    console.info('[MockEEGService] Stream started with mode:', this.simulationMode);

    this.streamInterval = setInterval(() => {
      const dataPoint = this.generateMultiChannelDataPoint();
      this.dataBuffer.push(dataPoint);

      if (this.dataBuffer.length > SERVICE_BUFFER_SIZE) {
        this.dataBuffer.shift();
      }

      if (this.onDataReceivedCallback) {
        this.onDataReceivedCallback(dataPoint);
      }
    }, SAMPLE_INTERVAL_MS);
  }

  public stopStream(): void {
    if (!this.isRunning) {
      console.warn('[MockEEGService] Stream not running');
      return;
    }

    if (this.streamInterval !== null) {
      clearInterval(this.streamInterval);
      this.streamInterval = null;
    }

    this.isRunning = false;
    console.info('[MockEEGService] Stream stopped');
  }

  public setSimulationMode(mode: EEGSimulationMode): void {
    if (this.simulationMode === mode) {
      return;
    }

    this.simulationMode = mode;
    console.info('[MockEEGService] Mode changed to:', mode);

    if (this.onModeChangedCallback) {
      this.onModeChangedCallback(mode);
    }
  }

  public getCurrentMode(): EEGSimulationMode {
    return this.simulationMode;
  }

  public getBufferedData(): EEGDataPoint[] {
    return [...this.dataBuffer];
  }

  public clearBuffer(): void {
    this.dataBuffer = [];
    console.info('[MockEEGService] Buffer cleared');
  }

  // ── Multi-channel data generation ───────────────────────────────────────

  private generateMultiChannelDataPoint(): EEGDataPoint {
    const timestamp = Date.now();
    const channels: number[] = [];

    for (let ch = 0; ch < EEG_CHANNEL_COUNT; ch++) {
      const phase = CHANNEL_PHASE_OFFSETS[ch];
      const scale = CHANNEL_AMPLITUDE_SCALE[ch];
      let value: number;

      switch (this.simulationMode) {
        case EEGSimulationMode.NORMAL:
          value = this.generateNormalChannel(timestamp, phase, scale);
          break;
        case EEGSimulationMode.MODERATE:
          value = this.generateModerateChannel(timestamp, phase, scale);
          break;
        case EEGSimulationMode.SEIZURE:
          value = this.generateSeizureChannel(timestamp, phase, scale);
          break;
        default:
          value = this.generateNormalChannel(timestamp, phase, scale);
          break;
      }

      channels.push(Math.round(value * 100) / 100);
    }

    return { timestamp, channels };
  }

  private generateNormalChannel(t: number, phase: number, scale: number): number {
    const alpha = 5 * Math.sin(2 * Math.PI * 10 * t / 1000 + phase);
    const beta = 3 * Math.sin(2 * Math.PI * 20 * t / 1000 + phase * 1.5);
    const noise = (Math.random() - 0.5) * 5;
    return (alpha + beta + noise) * scale;
  }

  private generateModerateChannel(t: number, phase: number, scale: number): number {
    const alpha = 90 * Math.sin(2 * Math.PI * 10 * t / 1000 + phase);
    const beta = 29 * Math.sin(2 * Math.PI * 20 * t / 1000 + phase * 1.5);
    const noise = (Math.random() - 0.5) * 20;
    const spike = Math.random() > 0.95 ? 30 * Math.random() : 0;
    return (alpha + beta + noise + spike) * scale;
  }

  private generateSeizureChannel(t: number, phase: number, scale: number): number {
    const seizure = 25 * Math.sin(2 * Math.PI * 30 * t / 1000 + phase);
    const highAmp = 80 * Math.sin(2 * Math.PI * 15 * t / 1000 + phase * 0.8);
    const spikes = Math.random() > 0.8 ? 100 * Math.random() : 0;
    return Math.abs(seizure + highAmp + spikes) * scale;
  }

  public destroy(): void {
    this.stopStream();
    this.dataBuffer = [];
    this.onDataReceivedCallback = null;
    this.onModeChangedCallback = null;
    console.info('[MockEEGService] Destroyed');
  }
}

let mockEEGServiceInstance: MockEEGService | null = null;

export function getMockEEGService(): MockEEGService {
  if (!mockEEGServiceInstance) {
    mockEEGServiceInstance = new MockEEGService();
  }
  return mockEEGServiceInstance;
}
