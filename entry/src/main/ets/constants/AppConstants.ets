/**
 * Centralized application constants for the AuraS EEG monitoring app.
 */

// ── EEG Sampling ────────────────────────────────────────────────────────────

export const SAMPLING_RATE: number = 256;
export const SAMPLE_INTERVAL_MS: number = 1000 / SAMPLING_RATE;
export const SERVICE_BUFFER_SIZE: number = 2048;
export const ANALYSIS_WINDOW_SIZE: number = 256;

// ── EEG Channel Configuration ───────────────────────────────────────────────

export const EEG_CHANNEL_COUNT: number = 4;
export const EEG_CHANNEL_NAMES: string[] = ['AF7', 'AF8', 'TP9', 'TP10'];

// ── AI Model Configuration ──────────────────────────────────────────────────

export const MODEL_FILE_NAME: string = 'ultralight_cnn.ms';
export const MODEL_WINDOW_SIZE: number = 1024;
export const MODEL_STRIDE: number = 256;
export const MODEL_INPUT_CHANNELS: number = 4;
export const MODEL_INFERENCE_INTERVAL_MS: number = 1000;
export const SEIZURE_PROBABILITY_THRESHOLD: number = 0.5;
export const SEIZURE_PROB_ORANGE_THRESHOLD: number = 0.3;

// ── Preprocessing Configuration ─────────────────────────────────────────────

export const NOTCH_FREQUENCY_HZ: number = 50;
export const BANDPASS_LOW_HZ: number = 0.5;
export const BANDPASS_HIGH_HZ: number = 45;
export const FILTER_ORDER: number = 2;

// ── Risk Level Colors ───────────────────────────────────────────────────────

export const COLOR_RISK_GREEN: string = '#44E88C';
export const COLOR_RISK_ORANGE: string = '#E8A844';
export const COLOR_RISK_RED: string = '#E84444';

// ── UI Colors ───────────────────────────────────────────────────────────────

export const COLOR_BACKGROUND: string = '#0D0D1A';
export const COLOR_TITLE: string = '#8888AA';
export const COLOR_STATUS_TEXT: string = '#FFFFFF';
export const COLOR_TIME_LABEL: string = '#555577';
export const COLOR_SAFE_BUTTON: string = '#1A8A7E';
export const COLOR_ORB_CENTER: string = '#FFFFFF';

// ── Waveform ────────────────────────────────────────────────────────────────

export const WAVEFORM_UPDATE_INTERVAL_MS: number = 100;
export const WAVEFORM_MAX_POINTS: number = 200;

// ── Orb Animation ───────────────────────────────────────────────────────────

export const ORB_ANIM_DURATION: number = 2000;
export const ANIM_START_DELAY_MS: number = 100;
export const ORB_CENTER_SIZE: number = 50;
export const ORB_CENTER_OPACITY: number = 0.35;

export interface OrbRingConfig {
  size: number;
  opacityAnimated: number;
  opacityInitial: number;
  scale: number;
  delay: number;
}

export const ORB_RINGS: OrbRingConfig[] = [
  { size: 260, opacityAnimated: 0.02, opacityInitial: 0.06, scale: 1.12, delay: 0 },
  { size: 220, opacityAnimated: 0.04, opacityInitial: 0.12, scale: 1.10, delay: 300 },
  { size: 180, opacityAnimated: 0.08, opacityInitial: 0.20, scale: 1.08, delay: 600 },
  { size: 145, opacityAnimated: 0.12, opacityInitial: 0.30, scale: 1.06, delay: 900 },
  { size: 110, opacityAnimated: 0.25, opacityInitial: 0.50, scale: 1.05, delay: 1200 },
];
