import { describe, expect, it } from 'vitest';

import { createDefaultBuildState, normalizeRoleId, ROLE_IDS } from '../src/domain/state.js';
import { createTaskPlan, stepTaskPlan } from '../src/domain/tasks.js';

describe('role normalization', () => {
  it('maps legacy aliases to canonical role ids', () => {
    expect(normalizeRoleId('archer')).toBe('designer');
    expect(normalizeRoleId('designer')).toBe('designer');
    expect(normalizeRoleId('wanjinyou')).toBe('druid');
    expect(normalizeRoleId('unknown')).toBe('druid');
  });

  it('exposes seven canonical roles', () => {
    expect(ROLE_IDS).toEqual([
      'druid',
      'assassin',
      'mage',
      'summoner',
      'warrior',
      'paladin',
      'designer',
    ]);
  });
});

describe('default build state', () => {
  it('creates role-aware defaults with draft status', () => {
    const state = createDefaultBuildState('warrior');
    expect(state.roleId).toBe('warrior');
    expect(state.draftDirty).toBe(false);
    expect(state.routing.modelRoute).toBe('codex');
    expect(state.skills.installed.length).toBeGreaterThan(0);
    expect(state.equipment.slots.chest).toBeTruthy();
    expect(state.identity.assistantName).toBe('Clawd');
  });
});

describe('task plan lifecycle', () => {
  it('walks through runtime phases in order', () => {
    const plan = createTaskPlan({ prompt: '整理投资周报', stationId: 'task-desk' });
    expect(plan.steps.map((step) => step.state)).toEqual([
      'researching',
      'executing',
      'syncing',
      'idle',
    ]);

    const s1 = stepTaskPlan(plan, 0);
    const s2 = stepTaskPlan(plan, 1);
    const s3 = stepTaskPlan(plan, 2);
    const s4 = stepTaskPlan(plan, 3);

    expect(s1.state).toBe('researching');
    expect(s2.state).toBe('executing');
    expect(s3.state).toBe('syncing');
    expect(s4.state).toBe('idle');
    expect(s4.progress).toBe(100);
  });
});
