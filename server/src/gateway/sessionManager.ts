import type { Clock } from '../core/time.js';
import type { Session, Storage } from '../storage/storage.js';

export class SessionManager {
  private nextSessionNumber = 1;

  constructor(
    private readonly storage: Storage,
    private readonly clock: Clock
  ) {}

  async create(socketId: string, ip: string): Promise<Session> {
    const now = this.clock.now();
    const session: Session = {
      sessionId: `session-${this.nextSessionNumber++}`,
      socketId,
      accountId: null,
      playerId: null,
      shardId: null,
      ip,
      state: 'connected',
      lastHeartbeatAt: now,
      createdAt: now
    };
    await this.storage.sessions.upsert(session);
    return session;
  }

  async get(sessionId: string): Promise<Session | undefined> {
    return this.storage.sessions.get(sessionId);
  }

  async authenticate(sessionId: string, accountId: string, playerId: string): Promise<Session> {
    const session = await this.requireSession(sessionId);
    if (session.state !== 'connected' && session.state !== 'authenticated') {
      throw new Error('SESSION_NOT_CONNECTED');
    }

    const updated: Session = {
      ...session,
      accountId,
      playerId,
      state: 'authenticated',
      lastHeartbeatAt: this.clock.now()
    };
    await this.storage.sessions.upsert(updated);
    return updated;
  }

  async enterWorld(sessionId: string, shardId: string): Promise<Session> {
    const session = await this.requireSession(sessionId);
    if (session.state !== 'authenticated') {
      throw new Error('SESSION_NOT_AUTHENTICATED');
    }

    const updated: Session = {
      ...session,
      shardId,
      state: 'in_world',
      lastHeartbeatAt: this.clock.now()
    };
    await this.storage.sessions.upsert(updated);
    return updated;
  }

  async switchShard(sessionId: string, shardId: string): Promise<Session> {
    const session = await this.requireSession(sessionId);
    if (session.state !== 'in_world') {
      throw new Error('SESSION_NOT_IN_WORLD');
    }

    const updated: Session = {
      ...session,
      shardId,
      lastHeartbeatAt: this.clock.now()
    };
    await this.storage.sessions.upsert(updated);
    return updated;
  }

  async heartbeat(sessionId: string): Promise<Session> {
    const session = await this.requireSession(sessionId);
    const updated: Session = {
      ...session,
      lastHeartbeatAt: this.clock.now()
    };
    await this.storage.sessions.upsert(updated);
    return updated;
  }

  async disconnect(sessionId: string): Promise<void> {
    const session = await this.storage.sessions.get(sessionId);
    if (!session || session.state === 'disconnected') {
      return;
    }
    await this.storage.sessions.markDisconnected(sessionId, this.clock.now());
  }

  async findReconnectable(accountId: string, playerId: string, graceMs: number): Promise<Session | undefined> {
    return this.storage.sessions.findRecentDisconnected(accountId, playerId, graceMs, this.clock.now());
  }

  private async requireSession(sessionId: string): Promise<Session> {
    const session = await this.storage.sessions.get(sessionId);
    if (!session) {
      throw new Error('SESSION_NOT_FOUND');
    }
    return session;
  }
}
