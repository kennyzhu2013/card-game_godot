import { afterEach, describe, expect, it } from 'vitest';
import { createM3App, type M3App } from '../app.js';

describe('M3 admin routes', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('requires a bearer token for admin inspection', async () => {
    app = await createM3App({ port: 0, adminPort: 0, adminToken: 'test-admin-token' });

    const response = await fetch(`http://127.0.0.1:${app.adminPort}/admin/sessions`);

    expect(response.status).toBe(401);
  });

  it('fails closed when the admin token is not configured', async () => {
    app = await createM3App({ port: 0, adminPort: 0, adminToken: '' });

    const response = await fetch(`http://127.0.0.1:${app.adminPort}/admin/sessions`, {
      headers: { Authorization: 'Bearer ' }
    });

    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: 'ADMIN_DISABLED' });
  });

  it('inspects shard state and manages local test combat locks', async () => {
    app = await createM3App({ port: 0, adminPort: 0, adminToken: 'test-admin-token' });

    const created = await adminFetch(app.adminPort, '/admin/shards/m3-dev/combat-locks/test', {
      method: 'POST',
      body: JSON.stringify({ center: { x: 8, y: 8 }, radius: 3 })
    });
    expect(created.status).toBe(200);
    const createdBody = await created.json() as { lock: { combatLockId: string; state: string; hostileEntityIds: string[] } };
    expect(createdBody.lock).toMatchObject({ state: 'active', hostileEntityIds: ['wolf-1'] });

    const shard = await adminFetch(app.adminPort, '/admin/shards/m3-dev');
    expect(await shard.json()).toMatchObject({
      shardId: 'm3-dev',
      mapId: 'mist-harbor-test',
      entityCount: 4,
      activeLockCount: 1
    });

    const closed = await adminFetch(app.adminPort, `/admin/combat-locks/${createdBody.lock.combatLockId}/close`, {
      method: 'POST',
      body: JSON.stringify({ result: 'victory' })
    });
    expect(closed.status).toBe(200);
    expect(await closed.json()).toMatchObject({ lock: { state: 'closed' }, result: 'victory' });

    const locks = await adminFetch(app.adminPort, '/admin/shards/m3-dev/combat-locks');
    expect(await locks.json()).toEqual({ combatLocks: [] });
  });
});

function adminFetch(port: number, path: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`http://127.0.0.1:${port}${path}`, {
    ...init,
    headers: {
      Authorization: 'Bearer test-admin-token',
      'Content-Type': 'application/json',
      ...init.headers
    }
  });
}
