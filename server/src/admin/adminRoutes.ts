import express from 'express';
import type { Request, Response } from 'express';
import type { AdminCombatLockCloseResult, StateInspector } from './stateInspector.js';
import { validateProgressionSelfPatchPayload } from '../protocol/validators.js';

export interface AdminRoutesOptions {
  adminToken: string;
  inspector: StateInspector;
}

export function createAdminApp(options: AdminRoutesOptions): express.Express {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '32kb' }));
  app.use('/admin', requireAdminToken(options.adminToken));

  app.get('/admin/sessions', async (_request, response) => {
    response.json({ sessions: await options.inspector.listSessions() });
  });

  app.get('/admin/shards/:shardId', (request, response) => {
    const shard = options.inspector.inspectShard(request.params.shardId);
    if (!shard) {
      response.status(404).json({ error: 'SHARD_NOT_FOUND' });
      return;
    }
    response.json(shard);
  });

  app.get('/admin/shards/:shardId/deltas', async (request, response) => {
    response.json({ deltas: await options.inspector.listDeltas(request.params.shardId) });
  });

  app.get('/admin/shards/:shardId/combat-locks', (request, response) => {
    const combatLocks = options.inspector.listCombatLocks(request.params.shardId);
    if (!combatLocks) {
      response.status(404).json({ error: 'SHARD_NOT_FOUND' });
      return;
    }
    response.json({ combatLocks });
  });

  app.post('/admin/shards/:shardId/progression/:playerId/test', async (request, response) => {
    const input = validateProgressionSelfPatchPayload(request.body);
    if (!input.ok) {
      response.status(400).json({ error: input.code, message: input.message });
      return;
    }

    const patched = await options.inspector.patchProgression(
      request.params.shardId,
      request.params.playerId,
      input.value.patch,
      input.value.reason
    );
    if (!patched) {
      response.status(404).json({ error: 'SHARD_NOT_FOUND' });
      return;
    }
    if (!patched.ok) {
      response.status(400).json({ error: patched.code, message: patched.message });
      return;
    }
    response.json({ state: patched.state, selfPatch: patched.selfPatch });
  });

  app.post('/admin/shards/:shardId/combat-locks/test', (request, response) => {
    const input = validateCombatLockRequest(request.body);
    if (!input.ok) {
      response.status(400).json({ error: input.code, message: input.message });
      return;
    }

    const lock = options.inspector.createTestCombatLock(request.params.shardId, input.value);
    if (!lock) {
      response.status(404).json({ error: 'SHARD_NOT_FOUND' });
      return;
    }
    response.json({ lock });
  });

  app.post('/admin/shards/:shardId/weekly-reset/test', async (request, response) => {
    const reset = await options.inspector.triggerWeeklyReset(request.params.shardId);
    if (!reset) {
      response.status(404).json({ error: 'SHARD_NOT_FOUND' });
      return;
    }
    response.json(reset);
  });

  app.post('/admin/combat-locks/:combatLockId/close', async (request, response) => {
    const closeResult = validateCloseResult(request.body);
    if (!closeResult.ok) {
      response.status(400).json({ error: closeResult.code, message: closeResult.message });
      return;
    }

    const closed = await options.inspector.closeCombatLock(request.params.combatLockId, closeResult.value);
    if (!closed) {
      response.status(404).json({ error: 'COMBAT_LOCK_NOT_FOUND' });
      return;
    }
    response.json({ lock: closed.lock, result: closeResult.value, entity: closed.entity ?? null, delta: closed.delta ?? null });
  });

  app.use((_request, response) => {
    response.status(404).json({ error: 'NOT_FOUND' });
  });

  app.use((error: Error, _request: Request, response: Response, _next: () => void) => {
    response.status(500).json({ error: 'INTERNAL_ERROR', message: error.message });
  });

  return app;
}

function requireAdminToken(adminToken: string) {
  return (request: Request, response: Response, next: () => void): void => {
    if (adminToken.length === 0) {
      response.status(503).json({ error: 'ADMIN_DISABLED' });
      return;
    }
    if (request.get('authorization') !== `Bearer ${adminToken}`) {
      response.status(401).json({ error: 'UNAUTHORIZED' });
      return;
    }
    next();
  };
}

function validateCombatLockRequest(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return invalid('INVALID_BODY', 'Request body must be an object');
  }
  const body = value as Record<string, unknown>;
  if (!isGridPosition(body.center)) {
    return invalid('INVALID_CENTER', 'center must be an integer grid position');
  }
  if (body.radius !== undefined && (!Number.isInteger(body.radius) || Number(body.radius) < 0)) {
    return invalid('INVALID_RADIUS', 'radius must be a non-negative integer when present');
  }
  return {
    ok: true as const,
    value: {
      center: body.center,
      radius: body.radius as number | undefined
    }
  };
}

function validateCloseResult(value: unknown): { ok: true; value: AdminCombatLockCloseResult } | { ok: false; code: string; message: string } {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return invalid('INVALID_BODY', 'Request body must be an object');
  }
  const result = (value as Record<string, unknown>).result;
  if (result !== 'victory' && result !== 'defeat' && result !== 'cancelled') {
    return invalid('INVALID_RESULT', 'result must be victory, defeat, or cancelled');
  }
  return { ok: true as const, value: result };
}

function isGridPosition(value: unknown): value is { x: number; y: number } {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }
  const candidate = value as Record<string, unknown>;
  return Number.isInteger(candidate.x) && Number.isInteger(candidate.y);
}

function invalid(code: string, message: string) {
  return { ok: false as const, code, message };
}
