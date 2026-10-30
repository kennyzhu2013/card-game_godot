import { describe, expect, it } from 'vitest';
import { DevAuthService } from './auth.js';

describe('DevAuthService', () => {
  it('maps dev tokens to deterministic local identities', async () => {
    const result = await new DevAuthService().login('dev:one');

    expect(result).toEqual({
      accountId: 'account-one',
      playerId: 'player-one',
      displayName: 'Player one'
    });
  });

  it('rejects non-development tokens', async () => {
    await expect(new DevAuthService().login('prod-token')).rejects.toThrow('INVALID_DEV_TOKEN');
  });
});
