export interface M3ServerConfig {
  port: number;
  adminPort: number;
  heartbeatIntervalMs: number;
  heartbeatTimeoutMs: number;
  reconnectGraceMs: number;
  snapshotRateHz: number;
  aoiRadiusCells: number;
  maxMoveCellsPerSecond: number;
  combatLockRadiusCells: number;
  adminToken: string;
  rateLimitWindowMs: number;
  rateLimitMaxMessages: number;
}

export const defaultM3Config: M3ServerConfig = {
  port: Number(process.env.M3_PORT ?? 3001),
  adminPort: Number(process.env.M3_ADMIN_PORT ?? 3002),
  heartbeatIntervalMs: 10000,
  heartbeatTimeoutMs: 30000,
  reconnectGraceMs: 60000,
  snapshotRateHz: 5,
  aoiRadiusCells: 30,
  maxMoveCellsPerSecond: 3,
  combatLockRadiusCells: 6,
  adminToken: process.env.M3_ADMIN_TOKEN ?? '',
  rateLimitWindowMs: 1000,
  rateLimitMaxMessages: 30
};

export function createM3Config(overrides: Partial<M3ServerConfig> = {}): M3ServerConfig {
  return { ...defaultM3Config, ...overrides };
}
