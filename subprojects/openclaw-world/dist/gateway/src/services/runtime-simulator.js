import { stepTaskPlan } from "../domain/tasks.js";
export class RuntimeSimulator {
    store;
    broadcast;
    activeTaskId = null;
    constructor(store, broadcast) {
        this.store = store;
        this.broadcast = broadcast;
    }
    get isBusy() {
        return Boolean(this.activeTaskId);
    }
    async runTask(plan) {
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
