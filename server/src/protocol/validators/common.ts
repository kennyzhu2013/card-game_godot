export type ValidationResult<T> =
  | { ok: true; value: T }
  | { ok: false; code: string; message: string };

export function asObject(value: unknown): ValidationResult<Record<string, unknown>> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return invalid('INVALID_PAYLOAD', 'Payload must be an object');
  }
  return { ok: true, value: value as Record<string, unknown> };
}

export function nonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

export function boundedString(value: unknown, maxLength: number): value is string {
  return nonEmptyString(value) && value.length <= maxLength;
}

export function invalid<T>(code: string, message: string): ValidationResult<T> {
  return { ok: false, code, message };
}
