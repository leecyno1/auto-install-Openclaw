import path from 'node:path';

import { describe, expect, it } from 'vitest';

import { resolvePublicDir } from '../src/lib/paths.js';

describe('public dir resolution', () => {
  it('prefers explicit OPENCLAW_WORLD_PUBLIC_DIR', () => {
    const root = '/tmp/openclaw-world';
    const explicit = '/tmp/godot-web-export';

    expect(resolvePublicDir(root, explicit)).toBe(explicit);
  });

  it('falls back to dist/public inside project root', () => {
    const root = '/tmp/openclaw-world';

    expect(resolvePublicDir(root)).toBe(path.join(root, 'dist', 'public'));
  });
});
