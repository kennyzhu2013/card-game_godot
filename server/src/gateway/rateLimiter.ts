export interface FixedWindowRateLimiterOptions {
  maxMessages: number;
  windowMs: number;
}

export interface RateLimitCheck {
  ok: boolean;
  remaining: number;
  resetMs: number;
  code?: string;
}

interface RateWindow {
  startedAt: number;
  count: number;
}

export class FixedWindowRateLimiter {
  private readonly windows = new Map<string, RateWindow>();

  constructor(private readonly options: FixedWindowRateLimiterOptions) {}

  allow(sessionId: string, now: number): boolean {
    return this.check(sessionId, now).ok;
  }

  check(sessionId: string, now: number): RateLimitCheck {
    const existing = this.windows.get(sessionId);
    if (!existing || now - existing.startedAt >= this.options.windowMs) {
      this.windows.set(sessionId, { startedAt: now, count: 1 });
      return { ok: true, remaining: Math.max(0, this.options.maxMessages - 1), resetMs: this.options.windowMs };
    }

    const resetMs = Math.max(0, this.options.windowMs - (now - existing.startedAt));
    if (existing.count >= this.options.maxMessages) {
      return { ok: false, remaining: 0, resetMs };
    }

    existing.count += 1;
    return { ok: true, remaining: Math.max(0, this.options.maxMessages - existing.count), resetMs };
  }
}

export interface PerOpRateLimiterOptions {
  default: FixedWindowRateLimiterOptions;
  ops?: Record<string, FixedWindowRateLimiterOptions>;
  opCodes?: Record<string, string>;
}

export class PerOpRateLimiter {
  private readonly limiters = new Map<string, FixedWindowRateLimiter>();

  constructor(private readonly options: PerOpRateLimiterOptions) {}

  check(sessionId: string, op: string, now: number): RateLimitCheck {
    const result = this.limiterFor(op).check(`${sessionId}:${op}`, now);
    if (!result.ok && this.options.opCodes?.[op]) {
      return { ...result, code: this.options.opCodes[op] };
    }
    return result;
  }

  allow(sessionId: string, op: string, now: number): boolean {
    return this.check(sessionId, op, now).ok;
  }

  private limiterFor(op: string): FixedWindowRateLimiter {
    const existing = this.limiters.get(op);
    if (existing) {
      return existing;
    }
    const limiter = new FixedWindowRateLimiter(this.options.ops?.[op] ?? this.options.default);
    this.limiters.set(op, limiter);
    return limiter;
  }
}
