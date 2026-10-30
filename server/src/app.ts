import type { Server } from 'node:http';
import { createServer } from 'node:http';
import { createAdminApp } from './admin/adminRoutes.js';
import { StateInspector } from './admin/stateInspector.js';
import { createM3Config, type M3ServerConfig } from './core/config.js';
import { ClientOps, ServerOps } from './protocol/ops.js';
import { ProgressionErrorCodes } from './protocol/validators.js';
import { systemClock } from './core/time.js';
import { DevAuthService } from './gateway/auth.js';
import { PerOpRateLimiter } from './gateway/rateLimiter.js';
import { SessionManager } from './gateway/sessionManager.js';
import { createM3WebSocketGateway } from './gateway/wsServer.js';
import { createMemoryStorage } from './storage/memoryStorage.js';
import type { Storage } from './storage/storage.js';
import { MapTemplateRegistry } from './world/mapTemplateRegistry.js';
import { ShardRegistry } from './world/shardRegistry.js';

export interface M3App {
  wsPort: number;
  adminPort: number;
  stop(): Promise<void>;
}

export interface M3AppOverrides extends Partial<M3ServerConfig> {
  storage?: Storage;
}

export async function createM3App(overrides: M3AppOverrides = {}): Promise<M3App> {
  const { storage: storageOverride, ...configOverrides } = overrides;
  const config = createM3Config(configOverrides);
  const storage = storageOverride ?? createMemoryStorage();
  const templateRegistry = new MapTemplateRegistry(storage);
  const shardRegistry = new ShardRegistry({
    storage,
    clock: systemClock,
    templateRegistry,
    defaultsByMap: {
      'mist-harbor-test': {
        aoiRadiusCells: config.aoiRadiusCells,
        maxMoveCellsPerSecond: config.maxMoveCellsPerSecond,
        combatLockRadiusCells: config.combatLockRadiusCells
      }
    }
  });
  const shard = await shardRegistry.spawn({ shardId: 'm3-dev', mapId: 'mist-harbor-test' });
  const shards = shardRegistry.shardMap();
  const sessions = new SessionManager(storage, systemClock);
  const rateLimiter = new PerOpRateLimiter({
    default: {
      maxMessages: config.rateLimitMaxMessages,
      windowMs: config.rateLimitWindowMs
    },
    ops: {
      [ClientOps.SystemPing]: { maxMessages: 6, windowMs: 60_000 },
      [ClientOps.WorldMove]: { maxMessages: 20, windowMs: 1000 },
      [ClientOps.WorldInteract]: { maxMessages: 8, windowMs: 1000 },
      [ClientOps.MonsterEvade]: { maxMessages: 6, windowMs: 1000 },
      [ClientOps.ProgressionSubscribe]: { maxMessages: 1, windowMs: 60_000 },
      [ClientOps.ProgressionAcknowledgeMilestone]: { maxMessages: 4, windowMs: 1000 },
      [ClientOps.ShopBuy]: { maxMessages: 3, windowMs: 1000 },
      [ClientOps.ShopSell]: { maxMessages: 3, windowMs: 1000 },
      [ClientOps.ChatSay]: { maxMessages: 3, windowMs: 1000 },
      [ClientOps.ChatWhisper]: { maxMessages: 3, windowMs: 1000 },
      [ClientOps.ChatParty]: { maxMessages: 3, windowMs: 1000 },
      [ClientOps.AuthRefresh]: { maxMessages: 3, windowMs: 1000 }
    },
    opCodes: {
      [ClientOps.ProgressionSubscribe]: ProgressionErrorCodes.RateLimited,
      [ClientOps.ProgressionAcknowledgeMilestone]: ProgressionErrorCodes.RateLimited
    }
  });

  const gateway = await createM3WebSocketGateway({
    port: config.port,
    clock: systemClock,
    auth: new DevAuthService(),
    storage,
    sessions,
    shard,
    shardRegistry,
    templateRegistry,
    rateLimiter,
    snapshotRateHz: config.snapshotRateHz
  });

  const adminServer = await listen(createServer(createAdminApp({
    adminToken: config.adminToken,
    inspector: new StateInspector(storage, shards, {
      onCombatLockCreated: (lock) => gateway.broadcastCombatLock(lock),
      onCombatLockClosed: (result) => {
        gateway.broadcastCombatUnlock(result.lock);
        if (result.delta && result.interestedPlayerIds) {
          gateway.broadcastToPlayers(result.interestedPlayerIds, {
            op: ServerOps.WorldDelta,
            payload: {
              ok: true,
              ...(result.entity ? { entity: result.entity } : {}),
              delta: result.delta,
              interestedPlayerIds: result.interestedPlayerIds
            }
          });
        }
      },
      onWeeklyReset: (result) => {
        gateway.broadcastToPlayers(result.playerIds, {
          op: ServerOps.WeeklyReset,
          payload: result.reset
        });
      }
    })
  })), config.adminPort);

  return {
    wsPort: gateway.wsPort,
    adminPort: addressPort(adminServer),
    async stop(): Promise<void> {
      await gateway.stop();
      await closeServer(adminServer);
      await shardRegistry.closeAll();
    }
  };
}

function listen(server: Server, port: number): Promise<Server> {
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', () => {
      server.off('error', reject);
      resolve(server);
    });
  });
}

function closeServer(server: Server): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close((error) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    });
  });
}

function addressPort(server: Server): number {
  const address = server.address();
  if (!address || typeof address === 'string') {
    throw new Error('ADMIN_SERVER_PORT_UNAVAILABLE');
  }
  return address.port;
}
