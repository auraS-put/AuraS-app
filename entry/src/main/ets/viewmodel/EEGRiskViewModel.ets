
import { EEGDataPoint, EEGSimulationMode, getMockEEGService, MockEEGService } from '../services/MockEEGService';
import { EEGRingBuffer } from '../services/EEGRingBuffer';
import { EEGPreprocessor } from '../services/EEGPreprocessor';
import {
  getSeizurePredictionService, SeizurePredictionService, PredictionResult
} from '../services/SeizurePredictionService';
import { resourceManager } from '@kit.LocalizationKit';
import { WAVEFORM_MAX_POINTS } from '../constants/AppConstants';

export enum RiskLevel {
  GREEN = 'GREEN',
  ORANGE = 'ORANGE',
  RED = 'RED'
}

@ObservedV2
export class EEGMetrics {
  @Trace currentAmplitude: number = 0;
  @Trace meanAmplitude: number = 0;
  @Trace maxAmplitude: number = 0;
  @Trace seizureProbability: number = 0;
  @Trace inferenceCount: number = 0;
  @Trace modelLoaded: boolean = false;
  @Trace previewMode: boolean = false;
  @Trace dataPointCount: number = 0;
}

@ObservedV2
export class EEGRiskViewModel {
  @Trace riskLevel: RiskLevel = RiskLevel.GREEN;
  @Trace metrics: EEGMetrics = new EEGMetrics();

  private eegService: MockEEGService;
  private preprocessor: EEGPreprocessor;
  private ringBuffer: EEGRingBuffer;
  private predictionService: SeizurePredictionService;
  private recentFilteredSamples: number[] = [];
  private readonly maxRecentSamples: number = 2048;

  private onRiskLevelChangedCallback: ((level: RiskLevel) => void) | null = null;

  constructor() {
    this.eegService = getMockEEGService();
    this.preprocessor = new EEGPreprocessor();
    this.ringBuffer = new EEGRingBuffer();
    this.predictionService = getSeizurePredictionService();

    this.initializeListeners();
    console.info('[EEGRiskViewModel] Initialized with AI pipeline');
  }

  /**
   * Initialize the AI model. Must be called with resourceManager before startMonitoring().
   */
  public async initModel(resMgr: resourceManager.ResourceManager): Promise<boolean> {
    const success = await this.predictionService.loadModel(resMgr);
    this.metrics.modelLoaded = success;
    this.metrics.previewMode = this.predictionService.isRunningInPreviewMode();
    if (success) {
      console.info('[EEGRiskViewModel] AI model ready' +
        (this.metrics.previewMode ? ' (PREVIEW MODE)' : ' (real device)'));
    } else {
      console.error('[EEGRiskViewModel] AI model failed to load');
    }
    return success;
  }

  private initializeListeners(): void {
    // Each raw sample goes through: filter → ringBuffer
    this.eegService.onDataReceived((dataPoint: EEGDataPoint) => {
      this.onEEGDataReceived(dataPoint);
    });

    this.eegService.onModeChanged((mode: EEGSimulationMode) => {
      console.info('[EEGRiskViewModel] EEG mode changed to:', mode);
      this.ringBuffer.clear();
      this.preprocessor.resetState();
      this.recentFilteredSamples = [];
    });

    // When ringBuffer has a full window (4×1024), run inference
    this.ringBuffer.onWindowReady((window: number[][]) => {
      this.onWindowReady(window);
    });
  }

  private onEEGDataReceived(dataPoint: EEGDataPoint): void {
    // 1. Filter sample-by-sample (stateful IIR)
    const filtered = this.preprocessor.filterSample(dataPoint.channels);

    // 2. Push filtered sample into ring buffer
    this.ringBuffer.pushSample(filtered);

    // 3. Keep recent filtered channel 0 for waveform display
    this.recentFilteredSamples.push(filtered[0]);
    if (this.recentFilteredSamples.length > this.maxRecentSamples) {
      this.recentFilteredSamples = this.recentFilteredSamples.slice(-this.maxRecentSamples);
    }

    // 4. Update basic metrics for UI
    this.updateMetrics(filtered);
  }

  private async onWindowReady(window: number[][]): Promise<void> {
    if (!this.predictionService.isModelLoaded()) {
      return;
    }

    // Z-score normalize the complete window
    const normalized = this.preprocessor.normalizeWindow(window);

    // Run AI inference
    const result: PredictionResult | null = await this.predictionService.predict(normalized);

    if (result) {
      this.metrics.seizureProbability = Math.round(result.seizureProbability * 10000) / 10000;
      this.metrics.inferenceCount = this.predictionService.getInferenceCount();
      this.setRiskLevel(result.riskLevel);
    }
  }

  private updateMetrics(filteredSample: number[]): void {
    this.metrics.currentAmplitude = Math.round(filteredSample[0] * 100) / 100;
    this.metrics.dataPointCount = this.ringBuffer.getSampleCount();

    // Running mean/max from recent samples
    if (this.recentFilteredSamples.length > 0) {
      const recent = this.recentFilteredSamples;
      const len = recent.length;
      let sum = 0;
      let maxAbs = 0;
      for (let i = 0; i < len; i++) {
        sum += recent[i];
        const abs = Math.abs(recent[i]);
        if (abs > maxAbs) {
          maxAbs = abs;
        }
      }
      this.metrics.meanAmplitude = Math.round((sum / len) * 100) / 100;
      this.metrics.maxAmplitude = Math.round(maxAbs * 100) / 100;
    }
  }

  private setRiskLevel(newLevel: RiskLevel): void {
    if (this.riskLevel !== newLevel) {
      const oldLevel = this.riskLevel;
      this.riskLevel = newLevel;
      console.info(`[EEGRiskViewModel] Risk level: ${oldLevel} -> ${newLevel} (prob=${this.metrics.seizureProbability})`);

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
    const samples = this.recentFilteredSamples;
    if (samples.length === 0) {
      return [];
    }
    if (samples.length <= maxPoints) {
      return [...samples];
    }
    const step = samples.length / maxPoints;
    const result: number[] = [];
    for (let i = 0; i < maxPoints; i++) {
      result.push(samples[Math.floor(i * step)]);
    }
    return result;
  }

  public clearBuffers(): void {
    this.ringBuffer.clear();
    this.preprocessor.resetState();
    this.recentFilteredSamples = [];
    this.eegService.clearBuffer();
    this.riskLevel = RiskLevel.GREEN;
    this.metrics.seizureProbability = 0;
    this.metrics.currentAmplitude = 0;
    this.metrics.meanAmplitude = 0;
    this.metrics.maxAmplitude = 0;
    this.metrics.dataPointCount = 0;
  }

  public destroy(): void {
    this.stopMonitoring();
    this.onRiskLevelChangedCallback = null;
    this.recentFilteredSamples = [];
    this.predictionService.destroy();
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
