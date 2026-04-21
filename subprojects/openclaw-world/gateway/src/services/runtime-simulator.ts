import type {
  BuildState,
  RuntimeState,
  TaskPlan,
  WorldState,
} from "../../../shared/world-model.js";
import { stepTaskPlan } from "../domain/tasks.js";
import type { WorldStore } from "./store.js";

export type BroadcastFn = (payload: {
  build?: BuildState;
  runtime?: RuntimeState;
  tasks?: TaskPlan[];
  world?: WorldState;
  reason: string;
}) => void;

export class RuntimeSimulator {
  private activeTaskId: string | null = null;

  constructor(
    private readonly store: WorldStore,
    private readonly broadcast: BroadcastFn,
  ) {}

  get isBusy(): boolean {
    return Boolean(this.activeTaskId);
  }

  async runTask(plan: TaskPlan): Promise<void> {
    this.activeTaskId = plan.id;
    this.store.appendTask(plan);

    for (let index = 0; index < plan.steps.length; index += 1) {
      const step = stepTaskPlan(plan, index);
      this.store.setRuntime({
        state: step.state,
        detail: step.detail,
        progress: step.progress,
        stationId: step.stationId,
        currentTaskId: plan.id,
        currentPrompt: plan.prompt,
        source: "world-gateway",
      });
      this.broadcast({
        runtime: this.store.runtime,
        tasks: this.store.tasks,
        world: this.store.world,
        reason: "runtime-step",
      });
      if (step.delayMs > 0) {
        await new Promise((resolve) => setTimeout(resolve, step.delayMs));
      }
    }

    this.store.completeTask(true, `已完成: ${plan.prompt}`);
    this.store.setRuntime({
      state: "idle",
      detail: "基地待命中",
      progress: 0,
      stationId: "role-altar",
      currentTaskId: null,
      currentPrompt: null,
      source: "world-gateway",
    });
    this.activeTaskId = null;
    this.broadcast({
      runtime: this.store.runtime,
      tasks: this.store.tasks,
      world: this.store.world,
      reason: "runtime-idle",
    });
  }
}
