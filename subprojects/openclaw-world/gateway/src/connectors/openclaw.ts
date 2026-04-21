import fs from "node:fs";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";

import type { BuildState, RuntimeState } from "../../../shared/world-model.js";
import { repoRoot } from "../lib/paths.js";
import { normalizeRoleId } from "../domain/state.js";
import { readJsonFile, writeJsonFile } from "../lib/json-file.js";

const homeDir = process.env.HOME || "";
const openclawHome = path.join(homeDir, ".openclaw");
const openclawStatusUrl =
  process.env.OPENCLAW_STATUS_URL || "http://127.0.0.1:13145/status";
const openclawSkillsDir = path.join(openclawHome, "skills");
const managedSkillsFile = path.join(
  openclawHome,
  "profile",
  "world-managed-skills.json",
);
const worldBuildMirror = path.join(
  openclawHome,
  "profile",
  "openclaw-world-build.json",
);
const reserveSkillsDir = path.join(repoRoot, "skills", "default");

export interface ApplyResult {
  applied: boolean;
  adapterMode: "openclaw-cli" | "local-only";
  installedSkills: string[];
  removedSkills: string[];
  missingSkills: string[];
  warnings: string[];
}

function hasOpenClawCli(): boolean {
  const result = spawnSync("bash", ["-lc", "command -v openclaw >/dev/null 2>&1"]);
  return result.status === 0;
}

function runConfigSet(key: string, value: string): void {
  spawn(
    "bash",
    ["-lc", `openclaw config set ${JSON.stringify(key)} ${JSON.stringify(value)}`],
    {
      detached: true,
      stdio: "ignore",
    },
  ).unref();
}

function safeSkillIdList(input: string[]): string[] {
  return [...new Set(input.map((item) => String(item || "").trim()).filter(Boolean))];
}

function listInstalledSkillDirs(): string[] {
  try {
    return fs
      .readdirSync(openclawSkillsDir, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name);
  } catch {
    return [];
  }
}

function syncManagedSkills(desiredSkills: string[]): Pick<
  ApplyResult,
  "installedSkills" | "removedSkills" | "missingSkills"
> {
  fs.mkdirSync(openclawSkillsDir, { recursive: true });
  const managed = readJsonFile<{ managedSkills: string[] }>(managedSkillsFile, {
    managedSkills: [],
  });
  const previous = new Set(safeSkillIdList(managed.managedSkills));
  const desired = new Set(safeSkillIdList(desiredSkills));
  const installedSkills: string[] = [];
  const removedSkills: string[] = [];
  const missingSkills: string[] = [];

  for (const stale of previous) {
    if (desired.has(stale)) continue;
    const staleDir = path.join(openclawSkillsDir, stale);
    if (fs.existsSync(staleDir)) {
      fs.rmSync(staleDir, { recursive: true, force: true });
      removedSkills.push(stale);
    }
  }

  for (const skillId of desired) {
    const targetDir = path.join(openclawSkillsDir, skillId);
    if (fs.existsSync(targetDir)) {
      installedSkills.push(skillId);
      continue;
    }
    const sourceDir = path.join(reserveSkillsDir, skillId);
    if (!fs.existsSync(sourceDir)) {
      missingSkills.push(skillId);
      continue;
    }
    fs.cpSync(sourceDir, targetDir, { recursive: true });
    installedSkills.push(skillId);
  }

  writeJsonFile(managedSkillsFile, {
    updatedAt: new Date().toISOString(),
    managedSkills: [...desired].sort(),
  });

  return {
    installedSkills: installedSkills.sort(),
    removedSkills: removedSkills.sort(),
    missingSkills: missingSkills.sort(),
  };
}

export async function readOpenClawRuntime(
  previous: RuntimeState,
): Promise<{ reachable: boolean; runtime: RuntimeState }> {
  try {
    const response = await fetch(openclawStatusUrl, { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const payload = (await response.json()) as Record<string, unknown>;
    const stateText = String(
      payload.state || payload.status || payload.phase || previous.state,
    ).toLowerCase();
    const detail = String(payload.detail || payload.message || payload.text || previous.detail);
    const progress = Number(payload.progress || previous.progress || 0);
    const normalizedState = (
      ["idle", "researching", "executing", "syncing", "error"].includes(stateText)
        ? stateText
        : previous.state
    ) as RuntimeState["state"];
    return {
      reachable: true,
      runtime: {
        ...previous,
        state: normalizedState,
        detail,
        progress: Number.isFinite(progress)
          ? Math.max(0, Math.min(100, progress))
          : previous.progress,
        source: "openclaw-status",
        updatedAt: new Date().toISOString(),
      },
    };
  } catch {
    return { reachable: false, runtime: previous };
  }
}

export function applyBuildToOpenClaw(build: BuildState): ApplyResult {
  writeJsonFile(worldBuildMirror, build);
  const syncResult = syncManagedSkills(build.skills.installed);
  const warnings: string[] = [];

  if (hasOpenClawCli()) {
    const roleId = normalizeRoleId(build.roleId);
    runConfigSet("identity.role.id", roleId);
    runConfigSet("identity.role.name", roleId);
    runConfigSet("identity.name", build.identity.assistantName);
    runConfigSet("identity.personality", build.identity.personality);
    runConfigSet("identity.work_style", build.identity.workStyle);
    runConfigSet("vendor.control.profile.skillPack", build.routing.skillPack);
    runConfigSet("vendor.control.routing.mode", build.routing.modelRoute);
    return {
      applied: true,
      adapterMode: "openclaw-cli",
      warnings,
      ...syncResult,
    };
  }

  warnings.push("openclaw CLI not found, build applied to local mirror only");
  return {
    applied: true,
    adapterMode: "local-only",
    warnings,
    ...syncResult,
  };
}

export function dispatchTaskToConnector(taskPayload: unknown): {
  mode: "simulated" | "command";
  accepted: boolean;
} {
  const customCommand = String(process.env.OPENCLAW_WORLD_TASK_COMMAND || "").trim();
  if (!customCommand) {
    return { mode: "simulated", accepted: true };
  }
  const child = spawn("bash", ["-lc", customCommand], {
    detached: true,
    stdio: ["pipe", "ignore", "ignore"],
  });
  child.stdin.end(JSON.stringify(taskPayload));
  child.unref();
  return { mode: "command", accepted: true };
}

export function readInstalledSkillIds(): string[] {
  return listInstalledSkillDirs().sort();
}
