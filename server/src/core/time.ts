export interface Clock {
  now(): number;
}

export const systemClock: Clock = {
  now: () => Date.now()
};

export class ManualClock implements Clock {
  constructor(private current: number = 0) {}

  now(): number {
    return this.current;
  }

  advance(ms: number): void {
    this.current += ms;
  }
}
