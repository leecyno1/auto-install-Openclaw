function detailFor(state, prompt) {
    switch (state) {
        case 'researching':
            return `正在理解任务: ${prompt}`;
        case 'executing':
            return `正在处理任务: ${prompt}`;
        case 'syncing':
            return `正在回传结果: ${prompt}`;
        case 'idle':
            return `任务已完成: ${prompt}`;
        default:
            return prompt;
    }
}
export function createTaskPlan(input) {
    const prompt = String(input.prompt || '').trim() || '未命名任务';
    const steps = [
        { state: 'researching', stationId: 'skill-shelf', progress: 20, detail: detailFor('researching', prompt), delayMs: 800 },
        { state: 'executing', stationId: 'task-desk', progress: 62, detail: detailFor('executing', prompt), delayMs: 1000 },
        { state: 'syncing', stationId: 'status-mirror', progress: 88, detail: detailFor('syncing', prompt), delayMs: 700 },
        { state: 'idle', stationId: input.stationId, progress: 100, detail: detailFor('idle', prompt), delayMs: 0 },
    ];
    return {
        id: `task-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`,
        prompt,
        stationId: input.stationId,
        createdAt: new Date().toISOString(),
        steps,
    };
}
export function stepTaskPlan(plan, index) {
    const safeIndex = Math.max(0, Math.min(index, plan.steps.length - 1));
    return plan.steps[safeIndex];
}
