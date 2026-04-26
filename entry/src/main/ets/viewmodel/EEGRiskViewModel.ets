

// Current risk levels are based on simplified thresholds for demonstration purposes. In a real application,
// these would be determined by AI algorithms and clinical data
import { EEGDataPoint, EEGSimulationMode, getMockEEGService, MockEEGService } from "../services/MockEEGService";
import {
  ANALYSIS_WINDOW_SIZE,
  ANOMALY_THRESHOLD_UV,
  THRESHOLD_ORANGE_MIN_UV,
  THRESHOLD_RED_MIN_UV,
  THRESHOLD_RED_MAX_UV,
  ANOMALY_RATE_ORANGE,
  ANOMALY_RATE_RED,
  WAVEFORM_MAX_POINTS
} from '../constants/AppConstants';

export enum RiskLevel {
  GREEN = 'GREEN',    // Very low risk - normal brain activity
  ORANGE = 'ORANGE',  // Moderate risk - potential anomalies
  RED = 'RED'         // High risk - seizure detected
}

@ObservedV2
export class EEGMetrics {
  @Trace currentAmplitude: number = 0;    // Latest EEG amplitude (uV)
  @Trace meanAmplitude: number = 0;       // Mean of recent amplitudes
  @Trace maxAmplitude: number = 0;        // Peak amplitude in analysis window
  @Trace anomalyCount: number = 0;        // Number of anomalies detected
  @Trace dataPointCount: number = 0;      // Total samples in analysis window
}

@ObservedV2
export class EEGRiskViewModel {
  @Trace riskLevel: RiskLevel = RiskLevel.GREEN;
  
  @Trace metrics: EEGMetrics = new EEGMetrics();
  
  private recentDataBuffer: EEGDataPoint[] = [];
  
  private eegService: MockEEGService;
  
  private onRiskLevelChangedCallback: ((level: RiskLevel) => void) | null = null;

  constructor() {
    this.eegService = getMockEEGService();
    this.initializeListeners();
    console.info('[EEGRiskViewModel] Initialized');
  }

  private initializeListeners(): void {
    this.eegService.onDataReceived((dataPoint: EEGDataPoint) => {
      this.onEEGDataReceived(dataPoint);
    });

    this.eegService.onModeChanged((mode: EEGSimulationMode) => {
      console.info('[EEGRiskViewModel] EEG mode changed to:', mode);
      this.recentDataBuffer = [];
    });
  }

  private onEEGDataReceived(dataPoint: EEGDataPoint): void {
    this.recentDataBuffer.push(dataPoint);

    if (this.recentDataBuffer.length > ANALYSIS_WINDOW_SIZE) {
      this.recentDataBuffer.shift();
    }

    this.updateMetrics();

    const newRiskLevel = this.calculateRiskLevel();
    this.setRiskLevel(newRiskLevel);
  }

  private updateMetrics(): void {
    if (this.recentDataBuffer.length === 0) {
      this.metrics.currentAmplitude = 0;
      this.metrics.meanAmplitude = 0;
      this.metrics.maxAmplitude = 0;
      this.metrics.dataPointCount = 0;
      this.metrics.anomalyCount = 0;
      return;
    }

    const amplitudes: number[] = this.recentDataBuffer.map((point: EEGDataPoint) => point.amplitude);
    const sumAmplitude: number = amplitudes.reduce((sum: number, value: number) => sum + value, 0);
    const meanAmplitude: number = sumAmplitude / amplitudes.length;
    const maxAmplitude: number = Math.max(...amplitudes.map((value: number) => Math.abs(value)));

    this.metrics.currentAmplitude = this.recentDataBuffer[this.recentDataBuffer.length - 1].amplitude;
    this.metrics.meanAmplitude = Math.round(meanAmplitude * 100) / 100;
    this.metrics.maxAmplitude = Math.round(maxAmplitude * 100) / 100;
    this.metrics.dataPointCount = this.recentDataBuffer.length;
    this.metrics.anomalyCount = this.countAnomalies();
  }

  private countAnomalies(): number {
    return this.recentDataBuffer.filter(
      point => Math.abs(point.amplitude) > ANOMALY_THRESHOLD_UV
    ).length;
  }

  private calculateRiskLevel(): RiskLevel {
    if (this.recentDataBuffer.length === 0) {
      return RiskLevel.GREEN;
    }

    const meanAmplitude = this.metrics.meanAmplitude;
    const maxAmplitude = this.metrics.maxAmplitude;
    const anomalyRate = this.metrics.anomalyCount / this.recentDataBuffer.length;

    if (
      meanAmplitude > THRESHOLD_RED_MIN_UV ||
      maxAmplitude > THRESHOLD_RED_MAX_UV ||
      anomalyRate > ANOMALY_RATE_RED
    ) {
      return RiskLevel.RED;
    }

    if (
      meanAmplitude > THRESHOLD_ORANGE_MIN_UV ||
      anomalyRate > ANOMALY_RATE_ORANGE
    ) {
      return RiskLevel.ORANGE;
    }

    return RiskLevel.GREEN;
  }

  private setRiskLevel(newLevel: RiskLevel): void {
    if (this.riskLevel !== newLevel) {
      const oldLevel = this.riskLevel;
      this.riskLevel = newLevel;
      console.info(`[EEGRiskViewModel] Risk level changed: ${oldLevel} -> ${newLevel}`);

      if (this.onRiskLevelChangedCallback) {
        this.onRiskLevelChangedCallback(newLevel);
      }
    }
  }

  public onRiskLevelChanged(callback: (level: RiskLevel) => void): void {
    this.onRiskLevelChangedCallback = callback;
  }

  public getRiskLevel(): RiskLevel {
    return this.riskLevel;
  }

  public getMetrics(): EEGMetrics {
    return this.metrics;
  }

  public startMonitoring(): void {
    this.eegService.startStream();
    console.info('[EEGRiskViewModel] Monitoring started');
  }

  public stopMonitoring(): void {
    this.eegService.stopStream();
    console.info('[EEGRiskViewModel] Monitoring stopped');
  }

  public setSimulationMode(mode: EEGSimulationMode): void {
    this.eegService.setSimulationMode(mode);
  }

  public getSimulationMode(): EEGSimulationMode {
    return this.eegService.getCurrentMode();
  }

  public getWaveformData(maxPoints: number = WAVEFORM_MAX_POINTS): number[] {
    if (this.recentDataBuffer.length === 0) {
      return [];
    }
    const buffer = this.recentDataBuffer;
    if (buffer.length <= maxPoints) {
      return buffer.map((p: EEGDataPoint) => p.amplitude);
    }
    const step = buffer.length / maxPoints;
    const result: number[] = [];
    for (let i = 0; i < maxPoints; i++) {
      result.push(buffer[Math.floor(i * step)].amplitude);
    }
    return result;
  }

  public clearBuffers(): void {
    this.recentDataBuffer = [];
    this.eegService.clearBuffer();
    this.riskLevel = RiskLevel.GREEN;
    this.updateMetrics();
  }

  public destroy(): void {
    this.stopMonitoring();
    this.onRiskLevelChangedCallback = null;
    this.recentDataBuffer = [];
    console.info('[EEGRiskViewModel] Destroyed');
  }
}

let viewModelInstance: EEGRiskViewModel | null = null;


export function getEEGRiskViewModel(): EEGRiskViewModel {
  if (!viewModelInstance) {
    viewModelInstance = new EEGRiskViewModel();
  }
  return viewModelInstance;
}
