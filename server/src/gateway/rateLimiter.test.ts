import { describe, expect, it } from 'vitest';
import { FixedWindowRateLimiter, PerOpRateLimiter } from './rateLimiter.js';

describe('FixedWindowRateLimiter', () => {
  it('allows the configured number of messages per second and then resets', () => {
    const limiter = new FixedWindowRateLimiter({ maxMessages: 3, windowMs: 1000 });

    expect(limiter.allow('session-1', 1000)).toBe(true);
    expect(limiter.allow('session-1', 1100)).toBe(true);
    expect(limiter.allow('session-1', 1200)).toBe(true);
    expect(limiter.allow('session-1', 1300)).toBe(false);
    expect(limiter.allow('session-1', 2000)).toBe(true);
  });

  it('tracks each session independently', () => {
    const limiter = new FixedWindowRateLimiter({ maxMessages: 1, windowMs: 1000 });

    expect(limiter.allow('session-1', 1000)).toBe(true);
    expect(limiter.allow('session-2', 1000)).toBe(true);
    expect(limiter.allow('session-1', 1001)).toBe(false);
  });

  it('reports remaining quota and reset timing when rejecting a fixed window', () => {
    const limiter = new FixedWindowRateLimiter({ maxMessages: 1, windowMs: 1000 });

    expect(limiter.check('session-1', 1000)).toEqual({ ok: true, remaining: 0, resetMs: 1000 });
    expect(limiter.check('session-1', 1200)).toEqual({ ok: false, remaining: 0, resetMs: 800 });
  });

  it('tracks per-op buckets independently for the same session', () => {
    const limiter = new PerOpRateLimiter({
      default: { maxMessages: 2, windowMs: 1000 },
      ops: {
        'system.ping': { maxMessages: 1, windowMs: 1000 },
        'world.move': { maxMessages: 2, windowMs: 1000 }
      }
    });

    expect(limiter.check('session-1', 'system.ping', 1000)).toMatchObject({ ok: true, remaining: 0 });
    expect(limiter.check('session-1', 'system.ping', 1001)).toMatchObject({ ok: false, remaining: 0 });
    expect(limiter.check('session-1', 'world.move', 1002)).toMatchObject({ ok: true, remaining: 1 });
    expect(limiter.check('session-1', 'world.move', 1003)).toMatchObject({ ok: true, remaining: 0 });
    expect(limiter.check('session-1', 'world.move', 1004)).toMatchObject({ ok: false, remaining: 0 });
  });

  it('reports progression subscribe limits with progression-specific errors', () => {
    const limiter = new PerOpRateLimiter({
      default: { maxMessages: 30, windowMs: 1000 },
      ops: {
        'progression.subscribe': { maxMessages: 1, windowMs: 60_000 }
      },
      opCodes: {
        'progression.subscribe': 'PROGRESSION_RATE_LIMITED'
      }
    });

    expect(limiter.check('session-1', 'progression.subscribe', 1000)).toMatchObject({ ok: true, remaining: 0 });
    expect(limiter.check('session-1', 'progression.subscribe', 1500)).toMatchObject({
      ok: false,
      code: 'PROGRESSION_RATE_LIMITED',
      remaining: 0,
      resetMs: 59_500
    });
  });
});
