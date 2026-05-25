
import { EEGDataPoint, EEGSimulationMode, getMockEEGService, MockEEGService } from '../services/MockEEGService';
import { EEGRingBuffer } from '../services/EEGRingBuffer';
import { EEGPreprocessor } from '../services/EEGPreprocessor';
import {
  getSeizurePredictionService, SeizurePredictionService, PredictionResult
} from '../services/SeizurePredictionService';
import { getNotificationService } from '../services/NotificationService';
import { getEmergencySMSService } from '../services/EmergencySMSService';
import { resourceManager } from '@kit.LocalizationKit';
import { Logger } from '../utils/Logger';
import {
  WAVEFORM_MAX_POINTS, SEIZURE_PROBABILITY_THRESHOLD, SEIZURE_PROB_ORANGE_THRESHOLD,
  SAFETY_CONFIRM_TIMEOUT_MS,
  DEBUG_RAMP_UP_MS, DEBUG_HOLD_MS, DEBUG_RAMP_DOWN_MS,
  DEBUG_GREEN_CENTER, DEBUG_ORANGE_CENTER, DEBUG_RED_CENTER,
  RiskLevel
} from '../constants/AppConstants';

const log = new Logger('EEGRiskViewModel');

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
  @Trace safetyTimerActive: boolean = false;
  @Trace safetyTimerRemaining: number = 0;
  @Trace smsSent: boolean = false;  

  private eegService: MockEEGService;
  private preprocessor: EEGPreprocessor;
  private ringBuffer: EEGRingBuffer;
  private predictionService: SeizurePredictionService;
  private recentFilteredSamples: number[] = [];
  private readonly maxRecentSamples: number = 2048;
  private smsOnDemand: boolean = false;

  private onRiskLevelChangedCallback: ((level: RiskLevel) => void) | null = null;

  // Safety timer
  private safetyTimerId: number | null = null;
  private safetyCountdownId: number | null = null;
  private safetyTimerStartTime: number = 0;

  // Debug presentation scenario: ramp up → hold → ramp down
  private debugTargetLevel: RiskLevel | null = null;
  private debugProbCurrent: number = 0;
  private debugStartTime: number = 0;

  constructor() {
    this.eegService = getMockEEGService();
    this.preprocessor = new EEGPreprocessor();
    this.ringBuffer = new EEGRingBuffer();
    this.predictionService = getSeizurePredictionService();

    this.initializeListeners();
    log.info('Initialized with AI pipeline');
  }

  /**
   * Initialize the AI model. Must be called with resourceManager before startMonitoring().
   */
  public async initModel(resMgr: resourceManager.ResourceManager): Promise<boolean> {
    const success = await this.predictionService.loadModel(resMgr);
    this.metrics.modelLoaded = success;
    this.metrics.previewMode = this.predictionService.isRunningInPreviewMode();
    if (success) {
      log.info('AI model ready' +
        (this.metrics.previewMode ? ' (PREVIEW MODE)' : ' (real device)'));
    } else {
      log.error('AI model failed to load');
    }
    return success;
  }

  private initializeListeners(): void {
    // Each raw sample goes through: filter → ringBuffer
    this.eegService.onDataReceived((dataPoint: EEGDataPoint) => {
      this.onEEGDataReceived(dataPoint);
    });

    this.eegService.onModeChanged((mode: EEGSimulationMode) => {
      log.info('EEG mode changed to:', mode);
      this.ringBuffer.clear();
      this.preprocessor.resetState();
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

    // Debug scenario: skip real inference, probability is time-driven
    if (this.debugTargetLevel !== null) {
      this.updateDebugProbability();
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

  /**
   * Time-based debug probability for presentation demos.
   * Phases: ramp up → hold at target → ramp down to green.
   * Called from onWindowReady and getMetrics for smooth 500ms UI updates.
   */
  private updateDebugProbability(): void {
    if (this.debugTargetLevel === null) {
      return;
    }

    const elapsed = Date.now() - this.debugStartTime;
    const greenCenter = 0.05;
    const targetCenter = this.getDebugTargetCenter();
    let baseProb: number;

    if (elapsed < DEBUG_RAMP_UP_MS) {
      const t = elapsed / DEBUG_RAMP_UP_MS;
      baseProb = greenCenter + (targetCenter - greenCenter) * this.easeInOutCubic(t);
    } else if (elapsed < DEBUG_RAMP_UP_MS + DEBUG_HOLD_MS) {
      baseProb = targetCenter;
    } else if (elapsed < DEBUG_RAMP_UP_MS + DEBUG_HOLD_MS + DEBUG_RAMP_DOWN_MS) {
      const t = (elapsed - DEBUG_RAMP_UP_MS - DEBUG_HOLD_MS) / DEBUG_RAMP_DOWN_MS;
      baseProb = targetCenter + (greenCenter - targetCenter) * this.easeInOutCubic(t);
    } else {
      baseProb = greenCenter;
      this.debugStartTime = Date.now();
    }

    // Organic fluctuation from overlapping sine waves
    const wobble = Math.sin(elapsed / 800) * 0.015
      + Math.sin(elapsed / 1300) * 0.01
      + Math.sin(elapsed / 3100) * 0.008;

    // Smooth tracking with slight lag for natural feel
    const target = baseProb + wobble;
    this.debugProbCurrent += (target - this.debugProbCurrent) * 0.3;
    this.debugProbCurrent = Math.max(0.01, Math.min(0.95, this.debugProbCurrent));

    this.metrics.seizureProbability = Math.round(this.debugProbCurrent * 10000) / 10000;

    // Derive risk level from current probability and update UI + waveform
    const newLevel = this.debugProbToRiskLevel(this.debugProbCurrent);
    if (this.riskLevel !== newLevel) {
      this.setRiskLevel(newLevel);
    }
    this.syncSimulationModeForLevel(newLevel);
  }

  private getDebugTargetCenter(): number {
    switch (this.debugTargetLevel) {
      case RiskLevel.GREEN: return DEBUG_GREEN_CENTER;
      case RiskLevel.ORANGE: return DEBUG_ORANGE_CENTER;
      case RiskLevel.RED: return DEBUG_RED_CENTER;
      default: return DEBUG_GREEN_CENTER;
    }
  }

  private easeInOutCubic(t: number): number {
    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  }

  private debugProbToRiskLevel(prob: number): RiskLevel {
    if (prob >= SEIZURE_PROBABILITY_THRESHOLD) {
      return RiskLevel.RED;
    }
    if (prob >= SEIZURE_PROB_ORANGE_THRESHOLD) {
      return RiskLevel.ORANGE;
    }
    return RiskLevel.GREEN;
  }

  private syncSimulationModeForLevel(level: RiskLevel): void {
    let mode: EEGSimulationMode;
    switch (level) {
      case RiskLevel.GREEN: mode = EEGSimulationMode.NORMAL; break;
      case RiskLevel.ORANGE: mode = EEGSimulationMode.MODERATE; break;
      case RiskLevel.RED: mode = EEGSimulationMode.SEIZURE; break;
      default: mode = EEGSimulationMode.NORMAL; break;
    }
    if (this.eegService.getCurrentMode() !== mode) {
      this.eegService.setSimulationMode(mode);
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
      log.info(`Risk level: ${oldLevel} -> ${newLevel} (prob=${this.metrics.seizureProbability})`);

      this.handleRiskLevelTransition(oldLevel, newLevel);

      if (this.onRiskLevelChangedCallback) {
        this.onRiskLevelChangedCallback(newLevel);
      }
    }
  }

  private handleRiskLevelTransition(_oldLevel: RiskLevel, newLevel: RiskLevel): void {
    const notificationService = getNotificationService();

    if (newLevel === RiskLevel.RED) {
      notificationService.resetCooldown();
      notificationService.notifyHigh();
      this.startSafetyTimer();
    } else if (newLevel === RiskLevel.ORANGE) {
      this.cancelSafetyTimer();
      notificationService.notifyModerate();
    } else {
      this.cancelSafetyTimer();
      this.smsSent = false;
      this.smsOnDemand = false;
      notificationService.cancelAll();
    }
  }

  private startSafetyTimer(): void {
    this.cancelSafetyTimer();
    this.safetyTimerActive = true;
    this.smsSent = false;
    this.safetyTimerStartTime = Date.now();
    this.safetyTimerRemaining = SAFETY_CONFIRM_TIMEOUT_MS;

    this.safetyCountdownId = setInterval(() => {
      const elapsed = Date.now() - this.safetyTimerStartTime;
      this.safetyTimerRemaining = Math.max(0, SAFETY_CONFIRM_TIMEOUT_MS - elapsed);
    }, 1000);

    this.safetyTimerId = setTimeout(() => {
      this.onSafetyTimeout();
    }, SAFETY_CONFIRM_TIMEOUT_MS);

    log.info(`Safety timer started (${SAFETY_CONFIRM_TIMEOUT_MS / 1000}s)`);
  }

  private cancelSafetyTimer(): void {
    if (this.safetyTimerId !== null) {
      clearTimeout(this.safetyTimerId);
      this.safetyTimerId = null;
    }
    if (this.safetyCountdownId !== null) {
      clearInterval(this.safetyCountdownId);
      this.safetyCountdownId = null;
    }
    this.safetyTimerActive = false;
    this.safetyTimerRemaining = 0;
  }

  private async onSafetyTimeout(): Promise<void> {
    log.warn('Safety not confirmed — triggering emergency SMS');
    this.safetyTimerActive = false;
    this.safetyTimerRemaining = 0;
    this.smsSent = true;
    this.smsOnDemand = false;

    if (this.safetyCountdownId !== null) {
      clearInterval(this.safetyCountdownId);
      this.safetyCountdownId = null;
    }

    await getEmergencySMSService().sendEmergencySMS(this.riskLevel, this.smsOnDemand);
  }

  public async sendCaregiverSmsOnDemand(): Promise<void> {
    log.warn('triggering emergency SMS via user demand');
    this.safetyTimerActive = false;
    this.safetyTimerRemaining = 0;
    this.smsSent = true;
    this.smsOnDemand = true;
    if (this.safetyCountdownId !== null) {
      clearInterval(this.safetyCountdownId);
      this.safetyCountdownId = null;
    }

    await getEmergencySMSService().sendEmergencySMS(this.riskLevel, this.smsOnDemand);
  }

  public confirmSafety(): void {
    this.cancelSafetyTimer();
    this.smsSent = false;
    getNotificationService().cancelAll();
    log.info('Safety confirmed by user');
  }

  public onRiskLevelChanged(callback: (level: RiskLevel) => void): void {
    this.onRiskLevelChangedCallback = callback;
  }

  public getRiskLevel(): RiskLevel {
    return this.riskLevel;
  }

  public getMetrics(): EEGMetrics {
    if (this.debugTargetLevel !== null) {
      this.updateDebugProbability();
    }
    return this.metrics;
  }

  public startMonitoring(): void {
    this.eegService.startStream();
    log.info('Monitoring started');
  }

  public stopMonitoring(): void {
    this.eegService.stopStream();
    log.info('Monitoring stopped');
  }

  public setSimulationMode(mode: EEGSimulationMode): void {
    this.eegService.setSimulationMode(mode);
  }

  /**
   * Start a debug presentation scenario: probability ramps up from GREEN
   * to the target level, holds for 60s, then ramps back down to GREEN.
   * Pass null to cancel and return to real inference.
   */
  public setDebugLock(level: RiskLevel | null): void {
    this.debugTargetLevel = level;
    if (level !== null) {
      this.debugProbCurrent = 0.05;
      this.debugStartTime = Date.now();
      this.metrics.seizureProbability = this.debugProbCurrent;
      this.riskLevel = RiskLevel.GREEN;
      this.eegService.setSimulationMode(EEGSimulationMode.NORMAL);
      if (this.onRiskLevelChangedCallback) {
        this.onRiskLevelChangedCallback(RiskLevel.GREEN);
      }
      log.info(`Debug scenario → ${level} (ramp ${DEBUG_RAMP_UP_MS / 1000}s + hold ${DEBUG_HOLD_MS / 1000}s + down ${DEBUG_RAMP_DOWN_MS / 1000}s)`);
    }
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
    this.cancelSafetyTimer();
    this.onRiskLevelChangedCallback = null;
    this.recentFilteredSamples = [];
    this.predictionService.destroy();
    log.info('Destroyed');
  }
}

let viewModelInstance: EEGRiskViewModel | null = null;


export function getEEGRiskViewModel(): EEGRiskViewModel {
  if (!viewModelInstance) {
    viewModelInstance = new EEGRiskViewModel();
  }
  return viewModelInstance;
}
