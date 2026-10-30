import { describe, expect, it, vi } from 'vitest';
import { SnapshotScheduler } from './snapshotScheduler.js';

describe('SnapshotScheduler', () => {
  it('runs at the configured snapshot rate and can stop cleanly', () => {
    vi.useFakeTimers();
    let ticks = 0;
    const scheduler = new SnapshotScheduler({
      snapshotRateHz: 5,
      onTick: () => {
        ticks += 1;
      }
    });

    scheduler.start();
    vi.advanceTimersByTime(600);
    scheduler.stop();
    vi.advanceTimersByTime(600);

    expect(ticks).toBe(3);
    vi.useRealTimers();
  });
});
