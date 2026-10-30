export interface AuthResult {
  accountId: string;
  playerId: string;
  displayName: string;
}

export class DevAuthService {
  async login(token: string): Promise<AuthResult> {
    if (!token.startsWith('dev:')) {
      throw new Error('INVALID_DEV_TOKEN');
    }

    const suffix = token.slice(4) || 'player';
    return {
      accountId: `account-${suffix}`,
      playerId: `player-${suffix}`,
      displayName: `Player ${suffix}`
    };
  }
}
