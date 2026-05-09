/**
 * Real-time EEG signal preprocessing pipeline.
 *
 * Applies three stages matching the model's training preprocessing:
 *   1. Notch filter (50 Hz IIR) — removes EU power-line interference
 *   2. Bandpass filter (0.5–45 Hz, 2nd-order Butterworth) — isolates neural bands
 *   3. Z-score normalization — per-channel, per-window standardization
 *
 * Filters are implemented as cascaded biquad IIR sections operating
 * sample-by-sample (stateful). Z-score is a batch operation on complete windows.
 */
import {
  EEG_CHANNEL_COUNT,
  SAMPLING_RATE,
  NOTCH_FREQUENCY_HZ,
  BANDPASS_LOW_HZ,
  BANDPASS_HIGH_HZ
} from '../constants/AppConstants';

interface BiquadCoeffs {
  b0: number;
  b1: number;
  b2: number;
  a1: number;
  a2: number;
}

// Per-channel biquad state: [x[n-1], x[n-2], y[n-1], y[n-2]]
type BiquadState = number[];

export class EEGPreprocessor {
  private filterCoeffs: BiquadCoeffs[];
  // filterStates[stageIndex][channelIndex] = [x1, x2, y1, y2]
  private filterStates: BiquadState[][];

  constructor() {
    this.filterCoeffs = [
      EEGPreprocessor.designNotch(NOTCH_FREQUENCY_HZ, SAMPLING_RATE, 30),
      EEGPreprocessor.designHighpass(BANDPASS_LOW_HZ, SAMPLING_RATE),
      EEGPreprocessor.designLowpass(BANDPASS_HIGH_HZ, SAMPLING_RATE),
    ];

    this.filterStates = [];
    for (let stage = 0; stage < this.filterCoeffs.length; stage++) {
      const channelStates: BiquadState[] = [];
      for (let ch = 0; ch < EEG_CHANNEL_COUNT; ch++) {
        channelStates.push([0, 0, 0, 0]);
      }
      this.filterStates.push(channelStates);
    }

    console.info('[EEGPreprocessor] Initialized — notch:', NOTCH_FREQUENCY_HZ,
      'Hz, bandpass:', BANDPASS_LOW_HZ, '-', BANDPASS_HIGH_HZ, 'Hz');
  }

  /**
   * Filter a single multi-channel sample through the IIR cascade.
   * Must be called for every incoming sample to maintain filter state continuity.
   */
  public filterSample(channels: number[]): number[] {
    const result: number[] = [];

    for (let ch = 0; ch < channels.length; ch++) {
      let x = channels[ch];

      for (let stage = 0; stage < this.filterCoeffs.length; stage++) {
        x = EEGPreprocessor.applyBiquad(x, this.filterCoeffs[stage], this.filterStates[stage][ch]);
      }

      result.push(x);
    }

    return result;
  }

  /**
   * Z-score normalize a complete window: per channel, (x - mean) / std.
   * This is the final preprocessing step before packing the tensor for inference.
   */
  public normalizeWindow(window: number[][]): number[][] {
    const normalized: number[][] = [];

    for (let ch = 0; ch < window.length; ch++) {
      const channel = window[ch];
      const len = channel.length;

      let sum = 0;
      for (let i = 0; i < len; i++) {
        sum += channel[i];
      }
      const mean = sum / len;

      let varianceSum = 0;
      for (let i = 0; i < len; i++) {
        const diff = channel[i] - mean;
        varianceSum += diff * diff;
      }
      const std = Math.sqrt(varianceSum / len);

      // Guard against zero-variance (flat signal) — pass through zeros
      const normChannel: number[] = [];
      if (std < 1e-10) {
        for (let i = 0; i < len; i++) {
          normChannel.push(0);
        }
      } else {
        for (let i = 0; i < len; i++) {
          normChannel.push((channel[i] - mean) / std);
        }
      }

      normalized.push(normChannel);
    }

    return normalized;
  }

  public resetState(): void {
    for (let stage = 0; stage < this.filterStates.length; stage++) {
      for (let ch = 0; ch < this.filterStates[stage].length; ch++) {
        this.filterStates[stage][ch] = [0, 0, 0, 0];
      }
    }
  }

  // ── Biquad engine ───────────────────────────────────────────────────────

  private static applyBiquad(x: number, c: BiquadCoeffs, s: BiquadState): number {
    const y = c.b0 * x + c.b1 * s[0] + c.b2 * s[1] - c.a1 * s[2] - c.a2 * s[3];
    // Shift delay line: s = [x[n-1], x[n-2], y[n-1], y[n-2]]
    s[1] = s[0];
    s[0] = x;
    s[3] = s[2];
    s[2] = y;
    return y;
  }

  // ── Filter design (Audio EQ Cookbook formulas) ───────────────────────────

  /**
   * 2nd-order IIR notch (band-reject) filter.
   * Removes a narrow frequency band centered at f0.
   */
  private static designNotch(f0: number, fs: number, Q: number): BiquadCoeffs {
    const w0 = 2 * Math.PI * f0 / fs;
    const alpha = Math.sin(w0) / (2 * Q);
    const cosW0 = Math.cos(w0);
    const a0 = 1 + alpha;

    return {
      b0: 1 / a0,
      b1: -2 * cosW0 / a0,
      b2: 1 / a0,
      a1: -2 * cosW0 / a0,
      a2: (1 - alpha) / a0,
    };
  }

  /**
   * 2nd-order Butterworth highpass filter via bilinear transform.
   */
  private static designHighpass(fc: number, fs: number): BiquadCoeffs {
    const omega = Math.tan(Math.PI * fc / fs);
    const omega2 = omega * omega;
    const sqrt2 = Math.SQRT2;
    const a0 = omega2 + sqrt2 * omega + 1;

    return {
      b0: 1 / a0,
      b1: -2 / a0,
      b2: 1 / a0,
      a1: 2 * (omega2 - 1) / a0,
      a2: (omega2 - sqrt2 * omega + 1) / a0,
    };
  }

  /**
   * 2nd-order Butterworth lowpass filter via bilinear transform.
   */
  private static designLowpass(fc: number, fs: number): BiquadCoeffs {
    const omega = Math.tan(Math.PI * fc / fs);
    const omega2 = omega * omega;
    const sqrt2 = Math.SQRT2;
    const a0 = omega2 + sqrt2 * omega + 1;

    return {
      b0: omega2 / a0,
      b1: 2 * omega2 / a0,
      b2: omega2 / a0,
      a1: 2 * (omega2 - 1) / a0,
      a2: (omega2 - sqrt2 * omega + 1) / a0,
    };
  }
}
