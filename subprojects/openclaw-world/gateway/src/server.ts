import fs from "node:fs";
import path from "node:path";
import http, { type IncomingMessage, type ServerResponse } from "node:http";
import { spawnSync } from "node:child_process";
import { WebSocketServer, type RawData, type WebSocket } from "ws";

import type {
  BuildState,
  HomeStationId,
  RuntimeState,
  TaskPlan,
  WorldState,
} from "../../shared/world-model.js";
import { createTaskPlan } from "./domain/tasks.js";
import {
  applyBuildToOpenClaw,
  dispatchTaskToConnector,
  readOpenClawRuntime,
} from "./connectors/openclaw.js";
import { equipmentItemsForBuild, collectSkillCatalog, roleCards } from "./services/catalog.js";
import { publicDir } from "./lib/paths.js";
import { RuntimeSimulator } from "./services/runtime-simulator.js";
import { WorldStore } from "./services/store.js";

const port = Number(process.env.OPENCLAW_WORLD_PORT || 19200);
const host = process.env.OPENCLAW_WORLD_HOST || "127.0.0.1";

const contentTypes: Record<string, string> = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".mjs": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".woff2": "font/woff2",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".webp": "image/webp",
};

const store = new WorldStore();
let wsClients = 0;

function sendJson(res: ServerResponse, status: number, payload: unknown): void {
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  });
  res.end(JSON.stringify(payload));
}

async function readBody(req: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  if (!chunks.length) return {};
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function buildPayload() {
  return {
    build: store.build,
    roles: roleCards(),
    skills: collectSkillCatalog(store.build),
    equipment: equipmentItemsForBuild(store.build),
  };
}

function snapshotPayload() {
  return {
    build: store.build,
    runtime: store.runtime,
    world: store.world,
    tasks: store.tasks,
  };
}

function broadcast(payload: {
  build?: BuildState;
  runtime?: RuntimeState;
  tasks?: TaskPlan[];
  world?: WorldState;
  reason: string;
}) {
  const message = JSON.stringify({
    type: "world:update",
    ...payload,
  });
  for (const client of wss.clients) {
    if (client.readyState === 1) {
      client.send(message);
    }
  }
}

const simulator = new RuntimeSimulator(store, broadcast);

function resolveQuotaScript(): string {
  const candidates = [
    process.env.OPENCLAW_MEDIA_QUOTA_SCRIPT,
    path.resolve(process.cwd(), "../../../scripts/media_quota.py"),
    path.resolve(process.cwd(), "../../../../scripts/media_quota.py"),
    path.join(process.env.HOME || "", ".openclaw/.cache/auto-install-openclaw-repo/scripts/media_quota.py"),
  ].filter(Boolean) as string[];
  for (const candidate of candidates) {
    const resolved = path.resolve(candidate);
    if (fs.existsSync(resolved) && fs.statSync(resolved).isFile()) {
      return resolved;
    }
  }
  return "";
}

function reserveTextQuota(units = 1): { ok: boolean; reservationId?: string; reason?: string; message?: string; status?: unknown } {
  const script = resolveQuotaScript();
  if (!script) {
    return { ok: false, reason: "quota_script_missing", message: "quota script not found" };
  }
  const result = spawnSync(
    "python3",
    [script, "reserve", "--category", "text", "--units", String(Math.max(1, units)), "--tool", "openclaw-world-gateway"],
    { encoding: "utf8", env: process.env },
  );
  const raw = (result.stdout || "").trim() || (result.stderr || "").trim() || "{}";
  let payload: any = {};
  try {
    payload = JSON.parse(raw);
  } catch {
    payload = { ok: false, reason: "quota_parse_error", message: raw };
  }
  if (result.status === 0 && payload?.ok === true && payload?.reservation?.id) {
    return { ok: true, reservationId: String(payload.reservation.id), status: payload.status };
  }
  return {
    ok: false,
    reason: String(payload?.reason || "quota_error"),
    message: String(payload?.message || raw || `quota command failed: ${String(result.status ?? "unknown")}`),
    status: payload?.status,
  };
}

function commitQuotaReservation(reservationId?: string): void {
  if (!reservationId) return;
  const script = resolveQuotaScript();
  if (!script) return;
  spawnSync("python3", [script, "commit", "--id", reservationId], { encoding: "utf8", env: process.env });
}

function releaseQuotaReservation(reservationId?: string): void {
  if (!reservationId) return;
  const script = resolveQuotaScript();
  if (!script) return;
  spawnSync("python3", [script, "release", "--id", reservationId], { encoding: "utf8", env: process.env });
}

function serveStatic(req: IncomingMessage, res: ServerResponse): void {
  const requestedPath = new URL(req.url || "/", `http://${host}:${port}`).pathname;
  const safePath = requestedPath === "/" ? "/index.html" : requestedPath;
  const candidate = path.normalize(path.join(publicDir, safePath));
  const indexPath = path.join(publicDir, "index.html");
  const target = candidate.startsWith(publicDir) ? candidate : indexPath;
  const requestedExt = path.extname(safePath).toLowerCase();

  let finalPath = target;
  if (!(fs.existsSync(finalPath) && fs.statSync(finalPath).isFile())) {
    if (requestedPath !== "/" && requestedExt) {
      sendJson(res, 404, { ok: false, message: `asset not found: ${safePath}` });
      return;
    }
    finalPath = indexPath;
  }

  if (!fs.existsSync(finalPath)) {
    sendJson(res, 503, { ok: false, message: "world client not built" });
    return;
  }

  const ext = path.extname(finalPath).toLowerCase();
  res.writeHead(200, {
    "content-type": contentTypes[ext] || "application/octet-stream",
    "cache-control": ext === ".html" ? "no-store" : "public, max-age=600",
  });
  fs.createReadStream(finalPath).pipe(res);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || "/", `http://${host}:${port}`);

  if (req.method === "GET" && url.pathname === "/health") {
    sendJson(res, 200, { ok: true, status: "ok", port, host });
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/build") {
    sendJson(res, 200, { ok: true, ...buildPayload() });
    return;
  }

  if (req.method === "PUT" && url.pathname === "/api/build") {
    const body = (await readBody(req)) as Partial<BuildState>;
    const nextBuild: BuildState = {
      ...store.build,
      ...body,
      identity: { ...store.build.identity, ...(body.identity || {}) },
      routing: { ...store.build.routing, ...(body.routing || {}) },
      skills: { ...store.build.skills, ...(body.skills || {}) },
      equipment: { ...store.build.equipment, ...(body.equipment || {}) },
      updatedAt: new Date().toISOString(),
      draftDirty: true,
    };
    store.updateBuild(nextBuild);
    broadcast({ build: store.build, world: store.world, reason: "build-draft" });
    sendJson(res, 200, { ok: true, ...buildPayload() });
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/build/apply") {
    const result = applyBuildToOpenClaw(store.build);
    store.markBuildApplied();
    broadcast({ build: store.build, world: store.world, reason: "build-apply" });
    sendJson(res, 200, { ok: true, apply: result, ...buildPayload() });
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/runtime") {
    sendJson(res, 200, { ok: true, runtime: store.runtime });
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/tasks") {
    sendJson(res, 200, { ok: true, tasks: store.tasks });
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/world/state") {
    sendJson(res, 200, { ok: true, world: store.world });
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/world/scene") {
    const body = (await readBody(req)) as { scene?: WorldState["scene"] };
    store.setScene(body.scene === "shared-world" ? "shared-world" : "home-base");
    broadcast({ world: store.world, reason: "scene-change" });
    sendJson(res, 200, { ok: true, world: store.world });
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/world/station") {
    const body = (await readBody(req)) as { stationId?: HomeStationId };
    const stationId = body.stationId || "role-altar";
    store.setStation(stationId);
    broadcast({ world: store.world, reason: "station-change" });
    sendJson(res, 200, { ok: true, world: store.world });
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/tasks") {
    let reservationId: string | undefined;
    try {
      const body = (await readBody(req)) as { prompt?: string };
      const prompt = String(body.prompt || "").trim() || "未命名任务";
      const quota = reserveTextQuota(1);
      if (!quota.ok) {
        const status = quota.reason === "quota_exceeded" || quota.reason === "disabled" ? 429 : 503;
        sendJson(res, status, { ok: false, code: quota.reason || "quota_error", message: quota.message || "text quota rejected", quota: quota.status });
        return;
      }
      reservationId = quota.reservationId;
      const plan = createTaskPlan({ prompt, stationId: "task-desk" });
      const dispatch = dispatchTaskToConnector(plan);
      void simulator.runTask(plan);
      commitQuotaReservation(reservationId);
      reservationId = undefined;
      sendJson(res, 202, { ok: true, task: plan, tasks: store.tasks, dispatch });
    } catch (error) {
      releaseQuotaReservation(reservationId);
      sendJson(res, 500, { ok: false, message: error instanceof Error ? error.message : "task dispatch failed" });
    }
    return;
  }

  serveStatic(req, res);
});

const wss = new WebSocketServer({ server, path: "/ws/world" });

wss.on("connection", (socket: WebSocket) => {
  wsClients += 1;
  store.setConnection(store.world.connection.openclawReachable, wsClients);
  socket.send(
    JSON.stringify({
      type: "world:init",
      ...snapshotPayload(),
    }),
  );

  socket.on("message", (raw: RawData) => {
    try {
      const payload = JSON.parse(String(raw)) as {
        type?: string;
        scene?: WorldState["scene"];
        stationId?: HomeStationId;
      };
      if (payload.type === "scene:set") {
        store.setScene(payload.scene === "shared-world" ? "shared-world" : "home-base");
        broadcast({ world: store.world, reason: "scene-change" });
      }
      if (payload.type === "station:set" && payload.stationId) {
        store.setStation(payload.stationId);
        broadcast({ world: store.world, reason: "station-change" });
      }
    } catch {
      // ignore malformed payloads
    }
  });

  socket.on("close", () => {
    wsClients = Math.max(0, wsClients - 1);
    store.setConnection(store.world.connection.openclawReachable, wsClients);
  });
});

async function pollOpenClawStatus() {
  if (simulator.isBusy) return;
  const status = await readOpenClawRuntime(store.runtime);
  store.setConnection(status.reachable, wsClients);
  if (status.reachable) {
    store.setRuntime(status.runtime);
    broadcast({
      runtime: store.runtime,
      world: store.world,
      reason: "openclaw-status",
    });
  }
}

setInterval(() => {
  void pollOpenClawStatus();
}, 5000);

server.listen(port, host, () => {
  console.log(`OpenClaw World gateway listening on http://${host}:${port}`);
});
