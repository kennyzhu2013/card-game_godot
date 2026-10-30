import { describe, expect, it } from 'vitest';
import { HeartbeatPolicy } from './heartbeat.js';

describe('HeartbeatPolicy', () => {
  it('times out sessions after the configured heartbeat timeout', () => {
    const policy = new HeartbeatPolicy({ timeoutMs: 30000 });

    expect(policy.isTimedOut(1000, 30999)).toBe(false);
    expect(policy.isTimedOut(1000, 31000)).toBe(true);
  });
});
