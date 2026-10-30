export const LEGACY_MAP_ALIASES = new Map<string, string>([
  ['m3-test', 'mist-harbor-test']
]);

export function resolveCanonicalMapId(mapId: string): string {
  return LEGACY_MAP_ALIASES.get(mapId) ?? mapId;
}
