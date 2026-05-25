/**
 * Circular buffer for multi-channel EEG data.
 * Collects 4-channel samples and emits windows of MODEL_WINDOW_SIZE (1024)
 * with a stride of MODEL_STRIDE (256 samples = 1 second at 256 Hz).
 *
 * The 75% overlap between consecutive windows matches the model's training
 * configuration, ensuring consistent prediction quality.
 */
import {
  EEG_CHANNEL_COUNT,
  MODEL_WINDOW_SIZE,
  MODEL_STRIDE
} from '../constants/AppConstants';

export class EEGRingBuffer {
  private channels: number[][] = [];
  private samplesSinceLastEmit: number = 0;
  private onWindowReadyCallback: ((window: number[][]) => void) | null = null;
  private readonly maxBufferSize: number = MODEL_WINDOW_SIZE * 2;

  constructor() {
    for (let ch = 0; ch < EEG_CHANNEL_COUNT; ch++) {
      this.channels.push([]);
    }
  }

  public onWindowReady(callback: (window: number[][]) => void): void {
    this.onWindowReadyCallback = callback;
  }

  public pushSample(channelValues: number[]): void {
    for (let ch = 0; ch < EEG_CHANNEL_COUNT; ch++) {
      this.channels[ch].push(channelValues[ch]);
    }
    this.samplesSinceLastEmit++;

    // Prevent unbounded growth
    if (this.channels[0].length > this.maxBufferSize) {
      const trim = this.channels[0].length - this.maxBufferSize;
      for (let ch = 0; ch < EEG_CHANNEL_COUNT; ch++) {
        this.channels[ch] = this.channels[ch].slice(trim);
      }
    }

    // Emit window when stride reached and enough data accumulated
    if (this.samplesSinceLastEmit >= MODEL_STRIDE &&
        this.channels[0].length >= MODEL_WINDOW_SIZE) {
      this.emitWindow();
    }
  }

  private emitWindow(): void {
    this.samplesSinceLastEmit = 0;

    const start = this.channels[0].length - MODEL_WINDOW_SIZE;
    const window: number[][] = [];

    for (let ch = 0; ch < EEG_CHANNEL_COUNT; ch++) {
      window.push(this.channels[ch].slice(start, start + MODEL_WINDOW_SIZE));
    }

    if (this.onWindowReadyCallback) {
      this.onWindowReadyCallback(window);
    }
  }

  public getSampleCount(): number {
    return this.channels[0].length;
  }

  public getLatestSamples(count: number, channel: number = 0): number[] {
    if (channel < 0 || channel >= EEG_CHANNEL_COUNT) {
      return [];
    }
    const ch = this.channels[channel];
    if (ch.length <= count) {
      return [...ch];
    }
    return ch.slice(ch.length - count);
  }

  public clear(): void {
    for (let ch = 0; ch < EEG_CHANNEL_COUNT; ch++) {
      this.channels[ch] = [];
    }
    this.samplesSinceLastEmit = 0;
  }
}
