export interface SnapshotSchedulerOptions {
  snapshotRateHz: number;
  onTick: () => void;
}

export class SnapshotScheduler {
  private timer: ReturnType<typeof setInterval> | undefined;

  constructor(private readonly options: SnapshotSchedulerOptions) {}

  start(): void {
    if (this.timer) {
      return;
    }
    const intervalMs = 1000 / this.options.snapshotRateHz;
    this.timer = setInterval(() => this.options.onTick(), intervalMs);
  }

  stop(): void {
    if (!this.timer) {
      return;
    }
    clearInterval(this.timer);
    this.timer = undefined;
  }
}
