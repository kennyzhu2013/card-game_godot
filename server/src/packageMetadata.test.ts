import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

interface PackageMetadata {
  name: string;
  description: string;
  main: string;
  private: boolean;
  license: string;
  scripts: Record<string, string>;
}

describe('public package metadata', () => {
  it('uses the maintained TypeScript server entrypoints', async () => {
    const packagePath = resolve(__dirname, '..', 'package.json');
    const metadata = JSON.parse(
      await readFile(packagePath, 'utf8')
    ) as PackageMetadata;

    expect(metadata.name).toBe('greycrown-authoritative-server');
    expect(metadata.description).toContain('Greycrown');
    expect(metadata.main).toBe('dist/main.js');
    expect(metadata.private).toBe(true);
    expect(metadata.license).toBe('UNLICENSED');
    expect(metadata.scripts.start).toBe('npm run m3:start');
    expect(metadata.scripts.dev).toBe('npm run m3:dev');
  });
});
