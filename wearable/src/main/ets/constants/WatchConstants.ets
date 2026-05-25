/**
 * UI constants optimized for Huawei Watch circular display (233×233 vp).
 */

import { OrbRingConfig } from './AppConstants';

// ── Watch Orb ───────────────────────────────────────────────────────────────

export const WATCH_ORB_CONTAINER_SIZE: number = 160;
export const WATCH_ORB_CENTER_SIZE: number = 26;
export const WATCH_ORB_CENTER_OPACITY: number = 0.40;

export const WATCH_ORB_RINGS: OrbRingConfig[] = [
  { size: 148, opacityAnimated: 0.03, opacityInitial: 0.06, scale: 1.10, delay: 0 },
  { size: 120, opacityAnimated: 0.06, opacityInitial: 0.14, scale: 1.08, delay: 300 },
  { size: 96, opacityAnimated: 0.10, opacityInitial: 0.24, scale: 1.06, delay: 600 },
  { size: 74, opacityAnimated: 0.18, opacityInitial: 0.36, scale: 1.05, delay: 900 },
  { size: 56, opacityAnimated: 0.30, opacityInitial: 0.55, scale: 1.04, delay: 1200 },
];

// ── Watch Typography ────────────────────────────────────────────────────────

export const WATCH_FONT_STATUS: number = 13;
export const WATCH_FONT_COUNTDOWN: number = 20;
export const WATCH_FONT_BUTTON: number = 11;
export const WATCH_FONT_TITLE: number = 10;

// ── Watch Layout ────────────────────────────────────────────────────────────

export const WATCH_BUTTON_HEIGHT: number = 32;
export const WATCH_BUTTON_WIDTH: string = '70%';
export const WATCH_BUTTON_RADIUS: number = 16;
