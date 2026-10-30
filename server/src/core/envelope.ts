import { pack, unpack } from 'msgpackr';

export interface Envelope<T = unknown> {
  id: number;
  op: string;
  payload: T;
  ts: number;
  protocolVersion?: number;
  clientToken?: string;
  shardId?: string;
}

export type ValidationResult<T> =
  | { ok: true; value: T }
  | { ok: false; code: string; message: string };

export type EnvelopeCodecMode = 'json' | 'msgpack';

export function validateEnvelope(value: unknown): ValidationResult<Envelope> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { ok: false, code: 'INVALID_ENVELOPE', message: 'Envelope must be an object' };
  }

  const candidate = value as Record<string, unknown>;
  if (!Number.isInteger(candidate.id) || Number(candidate.id) < 0) {
    return { ok: false, code: 'INVALID_ID', message: 'Envelope id must be a non-negative integer' };
  }
  if (typeof candidate.op !== 'string' || candidate.op.trim().length === 0) {
    return { ok: false, code: 'INVALID_OP', message: 'Envelope op must be a non-empty string' };
  }
  if (!Object.prototype.hasOwnProperty.call(candidate, 'payload')) {
    return { ok: false, code: 'INVALID_PAYLOAD', message: 'Envelope payload must be present' };
  }
  if (!Number.isFinite(candidate.ts) || Number(candidate.ts) < 0) {
    return { ok: false, code: 'INVALID_TS', message: 'Envelope ts must be a non-negative number' };
  }
  if (
    candidate.protocolVersion !== undefined
    && (!Number.isInteger(candidate.protocolVersion) || Number(candidate.protocolVersion) < 0)
  ) {
    return { ok: false, code: 'INVALID_PROTOCOL_VERSION', message: 'Envelope protocolVersion must be a non-negative integer when present' };
  }
  if (candidate.clientToken !== undefined && !nonEmptyString(candidate.clientToken)) {
    return { ok: false, code: 'INVALID_CLIENT_TOKEN', message: 'Envelope clientToken must be a non-empty string when present' };
  }
  if (candidate.shardId !== undefined && !nonEmptyString(candidate.shardId)) {
    return { ok: false, code: 'INVALID_SHARD_ID', message: 'Envelope shardId must be a non-empty string when present' };
  }

  const envelope: Envelope = {
    id: candidate.id as number,
    op: candidate.op,
    payload: candidate.payload,
    ts: candidate.ts as number,
    protocolVersion: candidate.protocolVersion === undefined ? 0 : candidate.protocolVersion as number
  };
  if (candidate.clientToken !== undefined) {
    envelope.clientToken = candidate.clientToken;
  }
  if (candidate.shardId !== undefined) {
    envelope.shardId = candidate.shardId;
  }
  return { ok: true, value: envelope };
}

export function encodeEnvelope(envelope: Envelope, mode: EnvelopeCodecMode = 'json'): Buffer {
  return mode === 'msgpack'
    ? Buffer.from(pack(envelope))
    : Buffer.from(JSON.stringify(envelope), 'utf8');
}

export function decodeEnvelope(data: Buffer | ArrayBuffer | string, mode: EnvelopeCodecMode = 'json'): Envelope {
  const raw = mode === 'msgpack' ? unpack(asBuffer(data)) : JSON.parse(asUtf8(data));
  const result = validateEnvelope(raw);
  if (!result.ok) {
    throw new Error(`${result.code}: ${result.message}`);
  }
  return result.value;
}

function asBuffer(data: Buffer | ArrayBuffer | string): Buffer {
  if (Buffer.isBuffer(data)) {
    return data;
  }
  if (typeof data === 'string') {
    return Buffer.from(data, 'utf8');
  }
  return Buffer.from(data);
}

function asUtf8(data: Buffer | ArrayBuffer | string): string {
  if (Buffer.isBuffer(data)) {
    return data.toString('utf8');
  }
  if (typeof data === 'string') {
    return data;
  }
  return Buffer.from(data).toString('utf8');
}

function nonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}
