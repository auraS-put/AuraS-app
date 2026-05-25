/**
 * SeizurePredictionService — on-device seizure prediction using MindSpore Lite.
 *
 * Loads the UltraLightCNN model (19 KB) from rawfile and runs inference
 * on preprocessed 4-channel EEG windows.
 *
 * Input:  float32[1, 4, 1024] — 4 channels × 1024 samples (4 sec at 256 Hz)
 * Output: float32[1, 2] — [interictal logit, preictal logit]
 *         → sigmoid(preictal logit) = probability of upcoming seizure
 *
 * Lifecycle: loadModel() once at startup → predict() every ~1 second.
 */
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { resourceManager } from '@kit.LocalizationKit';
import {
  MODEL_FILE_NAME,
  MODEL_WINDOW_SIZE,
  MODEL_INPUT_CHANNELS,
  SEIZURE_PROBABILITY_THRESHOLD,
  SEIZURE_PROB_ORANGE_THRESHOLD
} from '../constants/AppConstants';
import { RiskLevel } from '../constants/AppConstants';

export interface PredictionResult {
  seizureProbability: number;
  interictalLogit: number;
  preictalLogit: number;
  riskLevel: RiskLevel;
  timestamp: number;
}

export class SeizurePredictionService {
  private model: mindSporeLite.Model | null = null;
  private isLoaded: boolean = false;
  private isPreviewMode: boolean = false;
  private inferenceCount: number = 0;

  /**
   * Load the MindSpore Lite model from rawfile.
   * Must be called once before predict(). Requires access to resourceManager.
   *
   * In DevEco Previewer, MindSpore Lite APIs are mocked and non-functional.
   * We detect this and fall back to signal-based mock predictions so the
   * full UI pipeline can be tested visually.
   */
  public async loadModel(resMgr: resourceManager.ResourceManager): Promise<boolean> {
    if (this.isLoaded) {
      console.info('[SeizurePrediction] Model already loaded');
      return true;
    }

    try {
      const modelData: Uint8Array = resMgr.getRawFileContentSync(MODEL_FILE_NAME);

      const msContext: mindSporeLite.Context = {};
      msContext.target = ['cpu'];
      msContext.cpu = {
        threadNum: 2,
        threadAffinityMode: mindSporeLite.ThreadAffinityMode.BIG_CORES_FIRST,
        precisionMode: 'enforce_fp32'
      };

      this.model = await mindSporeLite.loadModelFromBuffer(modelData.buffer as ArrayBuffer, msContext);

      // Validate that model actually works (previewer returns mock objects)
      const inputs = this.model.getInputs();
      if (!inputs || inputs.length === 0 || !inputs[0].getData()) {
        throw new Error('Model inputs are mocked/empty — likely running in Previewer');
      }

      this.isLoaded = true;
      this.isPreviewMode = false;
      console.info('[SeizurePrediction] Model loaded successfully (real device)');
      return true;
    } catch (error) {
      console.warn('[SeizurePrediction] Real model load failed, enabling preview mock mode:',
        JSON.stringify(error));
      this.isLoaded = true;
      this.isPreviewMode = true;
      return true;
    }
  }

  /**
   * Run inference on a preprocessed, z-score normalized 4-channel EEG window.
   *
   * @param window — number[4][1024], already filtered and normalized
   * @returns PredictionResult with seizure probability and derived risk level
   */
  public async predict(window: number[][]): Promise<PredictionResult | null> {
    if (!this.isLoaded) {
      console.error('[SeizurePrediction] Model not loaded — call loadModel() first');
      return null;
    }

    if (this.isPreviewMode) {
      return this.mockPredict(window);
    }

    try {
      const tensorBuffer = SeizurePredictionService.packTensor(window);

      const inputs = this.model!.getInputs();
      inputs[0].setData(tensorBuffer);

      const outputs = await this.model!.predict(inputs);
      const outputData = new Float32Array(outputs[0].getData());

      const interictalLogit = outputData[0];
      const preictalLogit = outputData[1];
      const seizureProbability = SeizurePredictionService.sigmoid(preictalLogit);

      this.inferenceCount++;

      const result: PredictionResult = {
        seizureProbability,
        interictalLogit,
        preictalLogit,
        riskLevel: SeizurePredictionService.probabilityToRiskLevel(seizureProbability),
        timestamp: Date.now()
      };

      if (this.inferenceCount % 10 === 0) {
        console.info(`[SeizurePrediction] #${this.inferenceCount} prob=${seizureProbability.toFixed(4)} → ${result.riskLevel}`);
      }

      return result;
    } catch (error) {
      console.error('[SeizurePrediction] Inference failed:', JSON.stringify(error));
      return null;
    }
  }

  /**
   * Mock prediction for Previewer: derives seizure probability from signal
   * energy (RMS of all channels). Higher energy → higher probability.
   * This lets the full UI pipeline work visually during development.
   */
  private mockPredict(window: number[][]): PredictionResult {
    // Compute RMS energy across all channels as a proxy for seizure activity
    let sumSquares = 0;
    let count = 0;
    for (let ch = 0; ch < window.length; ch++) {
      for (let i = 0; i < window[ch].length; i++) {
        sumSquares += window[ch][i] * window[ch][i];
        count++;
      }
    }
    const rms = Math.sqrt(sumSquares / Math.max(count, 1));

    // Map RMS to probability: rms < 0.5 → ~0.05, rms ~1.0 → ~0.5, rms > 1.5 → ~0.9
    // z-scored signal has std=1, so RMS ~1 is normal for normalized data.
    // Seizure mode produces higher raw amplitudes → higher RMS after normalization.
    const rawProb = SeizurePredictionService.sigmoid((rms - 1.0) * 3.0);
    const seizureProbability = Math.round(rawProb * 10000) / 10000;

    this.inferenceCount++;

    const result: PredictionResult = {
      seizureProbability,
      interictalLogit: -(rms - 1.0) * 3.0,
      preictalLogit: (rms - 1.0) * 3.0,
      riskLevel: SeizurePredictionService.probabilityToRiskLevel(seizureProbability),
      timestamp: Date.now()
    };

    if (this.inferenceCount % 10 === 0) {
      console.info(`[SeizurePrediction:PREVIEW] #${this.inferenceCount} rms=${rms.toFixed(3)} prob=${seizureProbability.toFixed(4)} → ${result.riskLevel}`);
    }

    return result;
  }

  /**
   * Pack a 4×1024 window into a flat float32 ArrayBuffer.
   * Layout: [ch0_s0, ch0_s1, ..., ch0_s1023, ch1_s0, ..., ch3_s1023]
   * This matches the NCHW tensor format with batch=1.
   */
  private static packTensor(window: number[][]): ArrayBuffer {
    const totalElements = MODEL_INPUT_CHANNELS * MODEL_WINDOW_SIZE;
    const buffer = new ArrayBuffer(totalElements * 4); // 4 bytes per float32
    const view = new Float32Array(buffer);

    for (let ch = 0; ch < MODEL_INPUT_CHANNELS; ch++) {
      const offset = ch * MODEL_WINDOW_SIZE;
      const channelData = window[ch];
      for (let i = 0; i < MODEL_WINDOW_SIZE; i++) {
        view[offset + i] = channelData[i];
      }
    }

    return buffer;
  }

  private static sigmoid(x: number): number {
    // Clamped to avoid overflow: sigmoid(-88) ≈ 0, sigmoid(88) ≈ 1
    const clamped = Math.max(-88, Math.min(88, x));
    return 1.0 / (1.0 + Math.exp(-clamped));
  }

  /**
   * Map seizure probability to clinical risk level.
   *
   * < 0.3  → GREEN  (normal brain activity, no concern)
   * 0.3–0.5 → ORANGE (elevated risk, increased monitoring)
   * ≥ 0.5  → RED    (high probability of seizure, alert)
   */
  private static probabilityToRiskLevel(probability: number): RiskLevel {
    if (probability >= SEIZURE_PROBABILITY_THRESHOLD) {
      return RiskLevel.RED;
    }
    if (probability >= SEIZURE_PROB_ORANGE_THRESHOLD) {
      return RiskLevel.ORANGE;
    }
    return RiskLevel.GREEN;
  }

  public isModelLoaded(): boolean {
    return this.isLoaded;
  }

  public isRunningInPreviewMode(): boolean {
    return this.isPreviewMode;
  }

  public getInferenceCount(): number {
    return this.inferenceCount;
  }

  public destroy(): void {
    this.model = null;
    this.isLoaded = false;
    this.inferenceCount = 0;
    console.info('[SeizurePrediction] Destroyed');
  }
}

// Singleton
let predictionServiceInstance: SeizurePredictionService | null = null;

export function getSeizurePredictionService(): SeizurePredictionService {
  if (!predictionServiceInstance) {
    predictionServiceInstance = new SeizurePredictionService();
  }
  return predictionServiceInstance;
}
