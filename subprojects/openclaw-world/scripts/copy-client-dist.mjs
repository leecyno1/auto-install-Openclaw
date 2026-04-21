import { cpSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const from = path.resolve(root, '../gateway/dist/public');
const to = path.resolve(root, '../dist/public');
if (existsSync(from)) {
  cpSync(from, to, { recursive: true });
}
