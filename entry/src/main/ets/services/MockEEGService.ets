/**
 * Simulates a real-time EEG data stream for testing and development.
 * Provides three simulation modes: NORMAL, MODERATE, and SEIZURE.
 *
 * This is a temporary service until actual hardware (EEG wearable) is integrated.
 */

export interface EEGDataPoint {
  timestamp: number;
  amplitude: number; // in micro volts (µV)
  frequency: number; // in Hz
}

export enum EEGSimulationMode {
  NORMAL = 'NORMAL', // Low-amplitude, regular oscillations (~10-50 µV)
  MODERATE = 'MODERATE', // Increased noise and anomalies (~50-100 µV)
  SEIZURE = 'SEIZURE' // High-amplitude spikes (>200 µV)
}

interface GeneratedTypeLiteralInterface_1 {
  meanAmplitude: number;
  maxAmplitude: number;
  minAmplitude: number;
  dataPointCount: number;
}

export class MockEEGService {
  private simulationMode: EEGSimulationMode = EEGSimulationMode.NORMAL;
  private isRunning: boolean = false;
  private streamInterval: number | null = null;
  private dataBuffer: EEGDataPoint[] = [];
  private bufferSize: number = 1000; // Keep last 1000 data points

  private readonly SAMPLING_RATE = 250;
  private readonly SAMPLE_INTERVAL = 1000 / this.SAMPLING_RATE; // ~4ms per sample

  private onDataReceivedCallback: ((data: EEGDataPoint) => void) | null = null;
  private onModeChangedCallback: ((mode: EEGSimulationMode) => void) | null = null;

  constructor() {
    console.info('[MockEEGService] Initialized');
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
      const dataPoint = this.generateEEGDataPoint();
      this.dataBuffer.push(dataPoint);

      if (this.dataBuffer.length > this.bufferSize) {
        this.dataBuffer.shift();
      }

      if (this.onDataReceivedCallback) {
        this.onDataReceivedCallback(dataPoint);
      }
    }, this.SAMPLE_INTERVAL);
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
      console.warn('[MockEEGService] Already in mode:', mode);
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

  public getDataStatistics(): GeneratedTypeLiteralInterface_1 {
    if (this.dataBuffer.length === 0) {
      return {
        meanAmplitude: 0,
        maxAmplitude: 0,
        minAmplitude: 0,
        dataPointCount: 0
      };
    }

    const amplitudes = this.dataBuffer.map(d => d.amplitude);
    const sum = amplitudes.reduce((a, b) => a + b, 0);
    const mean = sum / amplitudes.length;
    const max = Math.max(...amplitudes);
    const min = Math.min(...amplitudes);

    return {
      meanAmplitude: Math.round(mean * 100) / 100,
      maxAmplitude: Math.round(max * 100) / 100,
      minAmplitude: Math.round(min * 100) / 100,
      dataPointCount: this.dataBuffer.length
    };
  }

  public clearBuffer(): void {
    this.dataBuffer = [];
    console.info('[MockEEGService] Buffer cleared');
  }

  private generateEEGDataPoint(): EEGDataPoint {
    const timestamp = Date.now();

    switch (this.simulationMode) {
      case EEGSimulationMode.NORMAL:
        return this.generateNormalEEG(timestamp);
      case EEGSimulationMode.MODERATE:
        return this.generateModerateEEG(timestamp);
      case EEGSimulationMode.SEIZURE:
        return this.generateSeizureEEG(timestamp);
      default:
        return this.generateNormalEEG(timestamp);
    }
  }

  private generateNormalEEG(timestamp: number): EEGDataPoint {
    const alpha = 5 * Math.sin(2 * Math.PI * 10 * timestamp / 1000); // 10 Hz alpha wave
    const beta = 3 * Math.sin(2 * Math.PI * 20 * timestamp / 1000); // 20 Hz beta wave
    const noise = (Math.random() - 0.5) * 5; // Small noise

    const amplitude = alpha + beta + noise;

    return {
      timestamp,
      amplitude: Math.round(amplitude * 100) / 100,
      frequency: 10
    };
  }

  private generateModerateEEG(timestamp: number): EEGDataPoint {
    const alpha = 90 * Math.sin(2 * Math.PI * 10 * timestamp / 1000);
    const beta = 29 * Math.sin(2 * Math.PI * 20 * timestamp / 1000);
    const noise = (Math.random() - 0.5) * 20;

    const spike = Math.random() > 0.95 ? 30 * Math.random() : 0;

    const amplitude = alpha + beta + noise + spike;

    return {
      timestamp,
      amplitude: Math.round(amplitude * 100) / 100,
      frequency: 10
    };
  }

  private generateSeizureEEG(timestamp: number): EEGDataPoint {
    // High-frequency, high-amplitude oscillations characteristic of seizures
    const seizureFrequency = 25 * Math.sin(2 * Math.PI * 30 * timestamp / 1000); // 30 Hz
    const highAmplitude = 80 * Math.sin(2 * Math.PI * 15 * timestamp / 1000); // 15 Hz with high amp
    const spikes = Math.random() > 0.8 ? 100 * Math.random() : 0; // Frequent spikes

    const amplitude = seizureFrequency + highAmplitude + spikes;

    return {
      timestamp,
      amplitude: Math.round(Math.abs(amplitude) * 100) / 100,
      frequency: 30
    };
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
