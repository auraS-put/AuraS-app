export class Logger {
  private tag: string;

  constructor(tag: string) {
    this.tag = `[${tag}]`;
  }

  public info(...params: string[]): void {
    console.info(this.tag, params.join(' '));
  }

  public warn(...params: string[]): void {
    console.warn(this.tag, params.join(' '));
  }

  public error(...params: string[]): void {
    console.error(this.tag, params.join(' '));
  }
}
