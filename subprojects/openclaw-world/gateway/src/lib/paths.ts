import path from "node:path";

export const projectRoot = process.cwd();
export const gatewayRoot = path.resolve(projectRoot, "gateway");
export const repoRoot = path.resolve(projectRoot, "..", "..");
export const dataDir =
  process.env.OPENCLAW_WORLD_DATA_DIR || path.resolve(projectRoot, "data");
export function resolvePublicDir(
  rootDir: string,
  explicitDir: string | undefined = process.env.OPENCLAW_WORLD_PUBLIC_DIR,
): string {
  if (explicitDir && explicitDir.trim()) {
    return path.resolve(rootDir, explicitDir);
  }
  return path.resolve(rootDir, "dist", "public");
}

export const publicDir = resolvePublicDir(projectRoot);
export const localClientRoot = path.resolve(projectRoot, "client");
