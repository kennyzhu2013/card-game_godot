export interface HeartbeatPolicyOptions {
  timeoutMs: number;
}

export class HeartbeatPolicy {
  constructor(private readonly options: HeartbeatPolicyOptions) {}

  isTimedOut(lastHeartbeatAt: number, now: number): boolean {
    return now - lastHeartbeatAt >= this.options.timeoutMs;
  }
}
