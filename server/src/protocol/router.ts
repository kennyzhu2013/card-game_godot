import type { Envelope } from '../core/envelope.js';
import { ServerOps } from './ops.js';

export interface DispatchInput {
  sessionId: string;
  envelope: Envelope;
}

export interface HandlerInput extends DispatchInput {
  payload: unknown;
}

export interface ProtocolRouterClock {
  now(): number;
}

export type HandlerResult = Omit<Envelope, 'id' | 'ts'> | Array<Omit<Envelope, 'id' | 'ts'>>;
export type ProtocolHandler = (input: HandlerInput) => Promise<HandlerResult>;

export class ProtocolRouter {
  private readonly clock: ProtocolRouterClock;
  private readonly handlers = new Map<string, ProtocolHandler>();

  constructor(clock: ProtocolRouterClock = { now: () => Date.now() }) {
    this.clock = clock;
  }

  register(op: string, handler: ProtocolHandler): void {
    this.handlers.set(op, handler);
  }

  async dispatch(input: DispatchInput): Promise<Envelope[]> {
    const handler = this.handlers.get(input.envelope.op);
    if (!handler) {
      return [this.error(input.envelope.id, 'UNKNOWN_OP', `Unknown op ${input.envelope.op}`, false)];
    }

    try {
      const result = await handler({ ...input, payload: input.envelope.payload });
      const messages = Array.isArray(result) ? result : [result];
      return messages.map((message) => ({
        id: input.envelope.id,
        op: message.op,
        payload: message.payload,
        ts: this.clock.now(),
        protocolVersion: input.envelope.protocolVersion ?? 0
      }));
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unhandled protocol error';
      return [this.error(input.envelope.id, 'HANDLER_ERROR', message, true)];
    }
  }

  private error(id: number, code: string, message: string, retryable: boolean): Envelope {
    return {
      id,
      op: ServerOps.WorldError,
      payload: { code, message, retryable },
      ts: this.clock.now(),
      protocolVersion: 0
    };
  }
}
