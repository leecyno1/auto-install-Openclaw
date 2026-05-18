import { defineConfig } from 'vite';
import path from 'node:path';

export default defineConfig({
  root: path.resolve(__dirname),
  publicDir: path.resolve(__dirname, 'public'),
  build: {
    outDir: path.resolve(__dirname, '../dist/public'),
    emptyOutDir: true,
  },
  server: {
    port: 19201,
    host: '127.0.0.1',
  },
});
