import path from "node:path";

import {
  HOME_STATIONS,
  type BuildState,
  type RuntimeMetrics,
  type RuntimeState,
  type TaskPlan,
  type WorldState,
} from "../../../shared/world-model.js";
import { createDefaultBuildState } from "../domain/state.js";
import { dataDir as defaultDataDir } from "../lib/paths.js";
import { ensureDir, readJsonFile, writeJsonFile } from "../lib/json-file.js";

function defaultRuntimeState(): RuntimeState {
  return {
    state: "idle",
    detail: "基地待命中",
    progress: 0,
    stationId: "role-altar",
    currentTaskId: null,
    currentPrompt: null,
    lastResult: "暂无任务结果",
    source: "world-gateway",
    updatedAt: new Date().toISOString(),
    sessionStartedAt: new Date().toISOString(),
    metrics: {
      tasksCreated: 0,
      tasksCompleted: 0,
      tasksSucceeded: 0,
      taskSuccessRate: 0,
      tokenConsumption: 0,
      skillUsageRate: 0,
      onlineMinutes: 0,
      level: 1,
      xp: 0,
    },
  };
}

function defaultWorldState(): WorldState {
  return {
    scene: "home-base",
    personaPanelStation: "role-altar",
    connection: {
      openclawReachable: false,
      wsClients: 0,
    },
    sharedWorld: {
      shellReady: true,
      message: "公共世界入口已建好骨架，第二阶段接入多人同步与协作任务。",
    },
  };
}

function safeMinutesBetween(startedAt: string): number {
  const parsed = Date.parse(startedAt);
  if (Number.isNaN(parsed)) return 0;
  return Math.max(0, Math.floor((Date.now() - parsed) / 60000));
}

export function computeMetrics(
  runtime: RuntimeState,
  build: BuildState,
): RuntimeMetrics {
  const tasksCompleted = runtime.metrics.tasksCompleted;
  const tasksSucceeded = runtime.metrics.tasksSucceeded;
  const taskSuccessRate =
    tasksCompleted > 0
      ? Number(((tasksSucceeded / tasksCompleted) * 100).toFixed(1))
      : 0;
  const skillUsageRate =
    build.skills.installed.length > 0
      ? Number(
          Math.min(100, (tasksCompleted / build.skills.installed.length) * 100).toFixed(1),
        )
      : 0;
  const xp = tasksSucceeded * 120 + build.skills.installed.length * 16;
  const level = Math.max(1, Math.floor(xp / 320) + 1);
  return {
    ...runtime.metrics,
    onlineMinutes: safeMinutesBetween(runtime.sessionStartedAt),
    taskSuccessRate,
    skillUsageRate,
    level,
    xp,
  };
}

interface WorldStoreOptions {
  dataDir?: string;
}

export class WorldStore {
  readonly dataDir: string;
  readonly buildFile: string;
  readonly runtimeFile: string;
  readonly worldFile: string;
  readonly tasksFile: string;

  build: BuildState;
  runtime: RuntimeState;
  world: WorldState;
  tasks: TaskPlan[];

  constructor(options: WorldStoreOptions = {}) {
    this.dataDir = options.dataDir || defaultDataDir;
    this.buildFile = path.join(this.dataDir, "build.json");
    this.runtimeFile = path.join(this.dataDir, "runtime.json");
    this.worldFile = path.join(this.dataDir, "world.json");
    this.tasksFile = path.join(this.dataDir, "tasks.json");

    ensureDir(this.dataDir);
    this.build = readJsonFile<BuildState>(this.buildFile, createDefaultBuildState("druid"));
    this.runtime = readJsonFile<RuntimeState>(this.runtimeFile, defaultRuntimeState());
    this.runtime.sessionStartedAt ||= new Date().toISOString();
    this.world = readJsonFile<WorldState>(this.worldFile, defaultWorldState());
    this.tasks = readJsonFile<TaskPlan[]>(this.tasksFile, []);
    this.runtime.metrics = computeMetrics(this.runtime, this.build);
    this.flush();
  }

  flush(): void {
    writeJsonFile(this.buildFile, this.build);
    writeJsonFile(this.runtimeFile, this.runtime);
    writeJsonFile(this.worldFile, this.world);
    writeJsonFile(this.tasksFile, this.tasks);
  }

  updateBuild(next: BuildState): void {
    this.build = {
      ...next,
      draftDirty: true,
      updatedAt: new Date().toISOString(),
    };
    this.runtime.metrics = computeMetrics(this.runtime, this.build);
    this.flush();
  }

  markBuildApplied(): void {
    this.build = {
      ...this.build,
      draftDirty: false,
      updatedAt: new Date().toISOString(),
    };
    this.flush();
  }

  setRuntime(partial: Partial<RuntimeState>): void {
    const merged = {
      ...this.runtime,
      ...partial,
      sessionStartedAt: partial.sessionStartedAt || this.runtime.sessionStartedAt,
    } as RuntimeState;
    this.runtime = {
      ...merged,
      metrics: computeMetrics(merged, this.build),
      updatedAt: new Date().toISOString(),
    };
    this.flush();
  }

  appendTask(plan: TaskPlan): void {
    this.tasks = [plan, ...this.tasks].slice(0, 60);
    this.runtime.metrics.tasksCreated += 1;
    this.flush();
  }

  completeTask(success: boolean, resultText: string): void {
    this.runtime.metrics.tasksCompleted += 1;
    if (success) this.runtime.metrics.tasksSucceeded += 1;
    this.runtime.lastResult = resultText;
    this.runtime.metrics.tokenConsumption += Math.max(
      120,
      Math.round((this.runtime.currentPrompt || "").length * 8),
    );
    this.runtime.metrics = computeMetrics(this.runtime, this.build);
    this.flush();
  }

  setScene(scene: WorldState["scene"]): void {
    this.world.scene = scene;
    this.flush();
  }

  setStation(stationId: keyof typeof HOME_STATIONS): void {
    this.world.personaPanelStation = stationId;
    this.flush();
  }

  setConnection(openclawReachable: boolean, wsClients: number): void {
    this.world.connection = { openclawReachable, wsClients };
    this.flush();
  }
}
