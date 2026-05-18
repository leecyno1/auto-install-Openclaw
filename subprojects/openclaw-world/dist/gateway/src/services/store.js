import path from "node:path";
import { createDefaultBuildState } from "../domain/state.js";
import { dataDir as defaultDataDir } from "../lib/paths.js";
import { ensureDir, readJsonFile, writeJsonFile } from "../lib/json-file.js";
function defaultRuntimeState() {
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
function defaultWorldState() {
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
function safeMinutesBetween(startedAt) {
    const parsed = Date.parse(startedAt);
    if (Number.isNaN(parsed))
        return 0;
    return Math.max(0, Math.floor((Date.now() - parsed) / 60000));
}
export function computeMetrics(runtime, build) {
    const tasksCompleted = runtime.metrics.tasksCompleted;
    const tasksSucceeded = runtime.metrics.tasksSucceeded;
    const taskSuccessRate = tasksCompleted > 0
        ? Number(((tasksSucceeded / tasksCompleted) * 100).toFixed(1))
        : 0;
    const skillUsageRate = build.skills.installed.length > 0
        ? Number(Math.min(100, (tasksCompleted / build.skills.installed.length) * 100).toFixed(1))
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
export class WorldStore {
    dataDir;
    buildFile;
    runtimeFile;
    worldFile;
    tasksFile;
    build;
    runtime;
    world;
    tasks;
    constructor(options = {}) {
        this.dataDir = options.dataDir || defaultDataDir;
        this.buildFile = path.join(this.dataDir, "build.json");
        this.runtimeFile = path.join(this.dataDir, "runtime.json");
        this.worldFile = path.join(this.dataDir, "world.json");
        this.tasksFile = path.join(this.dataDir, "tasks.json");
        ensureDir(this.dataDir);
        this.build = readJsonFile(this.buildFile, createDefaultBuildState("druid"));
        this.runtime = readJsonFile(this.runtimeFile, defaultRuntimeState());
        this.runtime.sessionStartedAt ||= new Date().toISOString();
        this.world = readJsonFile(this.worldFile, defaultWorldState());
        this.tasks = readJsonFile(this.tasksFile, []);
        this.runtime.metrics = computeMetrics(this.runtime, this.build);
        this.flush();
    }
    flush() {
        writeJsonFile(this.buildFile, this.build);
        writeJsonFile(this.runtimeFile, this.runtime);
        writeJsonFile(this.worldFile, this.world);
        writeJsonFile(this.tasksFile, this.tasks);
    }
    updateBuild(next) {
        this.build = {
            ...next,
            draftDirty: true,
            updatedAt: new Date().toISOString(),
        };
        this.runtime.metrics = computeMetrics(this.runtime, this.build);
        this.flush();
    }
    markBuildApplied() {
        this.build = {
            ...this.build,
            draftDirty: false,
            updatedAt: new Date().toISOString(),
        };
        this.flush();
    }
    setRuntime(partial) {
        const merged = {
            ...this.runtime,
            ...partial,
            sessionStartedAt: partial.sessionStartedAt || this.runtime.sessionStartedAt,
        };
        this.runtime = {
            ...merged,
            metrics: computeMetrics(merged, this.build),
            updatedAt: new Date().toISOString(),
        };
        this.flush();
    }
    appendTask(plan) {
        this.tasks = [plan, ...this.tasks].slice(0, 60);
        this.runtime.metrics.tasksCreated += 1;
        this.flush();
    }
    completeTask(success, resultText) {
        this.runtime.metrics.tasksCompleted += 1;
        if (success)
            this.runtime.metrics.tasksSucceeded += 1;
        this.runtime.lastResult = resultText;
        this.runtime.metrics.tokenConsumption += Math.max(120, Math.round((this.runtime.currentPrompt || "").length * 8));
        this.runtime.metrics = computeMetrics(this.runtime, this.build);
        this.flush();
    }
    setScene(scene) {
        this.world.scene = scene;
        this.flush();
    }
    setStation(stationId) {
        this.world.personaPanelStation = stationId;
        this.flush();
    }
    setConnection(openclawReachable, wsClients) {
        this.world.connection = { openclawReachable, wsClients };
        this.flush();
    }
}
