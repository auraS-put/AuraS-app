/**
 * Centralized application constants for the AuraS EEG monitoring app.
 */

// ── EEG Sampling ────────────────────────────────────────────────────────────

export const SAMPLING_RATE: number = 250;
export const SAMPLE_INTERVAL_MS: number = 1000 / SAMPLING_RATE;
export const SERVICE_BUFFER_SIZE: number = 1000;
export const ANALYSIS_WINDOW_SIZE: number = 250;

// ── Risk Level Thresholds ───────────────────────────────────────────────────

export const ANOMALY_THRESHOLD_UV: number = 100;
export const THRESHOLD_ORANGE_MIN_UV: number = 50;
export const THRESHOLD_RED_MIN_UV: number = 100;
export const THRESHOLD_RED_MAX_UV: number = 150;
export const ANOMALY_RATE_ORANGE: number = 0.05;
export const ANOMALY_RATE_RED: number = 0.20;

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
