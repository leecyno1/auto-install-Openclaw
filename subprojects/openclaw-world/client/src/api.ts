import type {
  BuildState,
  EquipmentItem,
  RoleProfile,
  RuntimeState,
  SkillCard,
  TaskPlan,
  WorldState,
} from "../../shared/world-model.js";

export interface BuildResponse {
  ok: boolean;
  build: BuildState;
  roles: RoleProfile[];
  skills: {
    installed: SkillCard[];
    reserve: SkillCard[];
  };
  equipment: {
    equipped: EquipmentItem[];
    inventory: EquipmentItem[];
  };
}

async function jsonFetch<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    cache: "no-store",
    headers: {
      "content-type": "application/json",
    },
    ...init,
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return (await response.json()) as T;
}

export const api = {
  build: () => jsonFetch<BuildResponse>("/api/build"),
  saveBuild: (build: BuildState) =>
    jsonFetch<BuildResponse>("/api/build", {
      method: "PUT",
      body: JSON.stringify(build),
    }),
  applyBuild: () =>
    jsonFetch<BuildResponse & { apply: unknown }>("/api/build/apply", {
      method: "POST",
      body: "{}",
    }),
  runtime: () => jsonFetch<{ ok: boolean; runtime: RuntimeState }>("/api/runtime"),
  tasks: () => jsonFetch<{ ok: boolean; tasks: TaskPlan[] }>("/api/tasks"),
  world: () => jsonFetch<{ ok: boolean; world: WorldState }>("/api/world/state"),
  setScene: (scene: WorldState["scene"]) =>
    jsonFetch<{ ok: boolean; world: WorldState }>("/api/world/scene", {
      method: "POST",
      body: JSON.stringify({ scene }),
    }),
  setStation: (stationId: string) =>
    jsonFetch<{ ok: boolean; world: WorldState }>("/api/world/station", {
      method: "POST",
      body: JSON.stringify({ stationId }),
    }),
  dispatchTask: (prompt: string) =>
    jsonFetch<{ ok: boolean; task: TaskPlan; tasks: TaskPlan[]; dispatch: unknown }>("/api/tasks", {
      method: "POST",
      body: JSON.stringify({ prompt }),
    }),
};
