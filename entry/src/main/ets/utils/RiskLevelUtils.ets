/**
 * Presentation helpers for RiskLevel — colors, status text, mapping to simulation modes.
 */
import { RiskLevel } from '../viewmodel/EEGRiskViewModel';
import { EEGSimulationMode } from '../services/MockEEGService';
import { COLOR_RISK_GREEN, COLOR_RISK_ORANGE, COLOR_RISK_RED } from '../constants/AppConstants';

export function getGlowColor(riskLevel: RiskLevel): string {
  switch (riskLevel) {
    case RiskLevel.GREEN:
      return COLOR_RISK_GREEN;
    case RiskLevel.ORANGE:
      return COLOR_RISK_ORANGE;
    case RiskLevel.RED:
      return COLOR_RISK_RED;
    default:
      return COLOR_RISK_GREEN;
  }
}

export function getStatusText(riskLevel: RiskLevel): string {
  switch (riskLevel) {
    case RiskLevel.GREEN:
      return 'Monitoring - All Clear';
    case RiskLevel.ORANGE:
      return 'Monitoring - Watchful';
    case RiskLevel.RED:
      return 'Monitoring - Attention';
    default:
      return 'Monitoring - All Clear';
  }
}

export function riskLevelToSimulationMode(riskLevel: RiskLevel): EEGSimulationMode {
  switch (riskLevel) {
    case RiskLevel.GREEN:
      return EEGSimulationMode.NORMAL;
    case RiskLevel.ORANGE:
      return EEGSimulationMode.MODERATE;
    case RiskLevel.RED:
      return EEGSimulationMode.SEIZURE;
    default:
      return EEGSimulationMode.NORMAL;
  }
}

export function formatTimeLabel(hoursAgo: number): string {
  const now = new Date();
  const past = new Date(now.getTime() - hoursAgo * 3600000);
  let hours = past.getHours();
  const ampm = hours >= 12 ? 'pm' : 'am';
  hours = hours % 12;
  if (hours === 0) {
    hours = 12;
  }
  return `${hours} ${ampm}`;
}
