import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { describe, expect, it } from 'vitest';

import { collectSkillCatalog } from '../src/services/catalog.js';
import { WorldStore } from '../src/services/store.js';

describe('world metrics', () => {
  it('computes online minutes from session start and task completion metrics', () => {
    const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'openclaw-world-data-'));
    const runtimeFile = path.join(dataDir, 'runtime.json');
    const startedAt = new Date(Date.now() - 95 * 60 * 1000).toISOString();

    fs.writeFileSync(
      runtimeFile,
      JSON.stringify(
        {
          state: 'idle',
          detail: 'ready',
          progress: 0,
          stationId: 'role-altar',
          currentTaskId: null,
          currentPrompt: null,
          lastResult: 'none',
          source: 'world-gateway',
          updatedAt: new Date().toISOString(),
          sessionStartedAt: startedAt,
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
        },
        null,
        2,
      ),
    );

    const store = new WorldStore({ dataDir });
    expect(store.runtime.metrics.onlineMinutes).toBeGreaterThanOrEqual(95);

    store.appendTask({
      id: 'task-1',
      prompt: '整理周报',
      stationId: 'task-desk',
      createdAt: new Date().toISOString(),
      steps: [],
    });
    store.setRuntime({ currentPrompt: '整理周报' });
    store.completeTask(true, 'done');

    expect(store.runtime.metrics.tasksCreated).toBe(1);
    expect(store.runtime.metrics.tasksCompleted).toBe(1);
    expect(store.runtime.metrics.tasksSucceeded).toBe(1);
    expect(store.runtime.metrics.taskSuccessRate).toBe(100);
    expect(store.runtime.metrics.tokenConsumption).toBeGreaterThan(0);
    expect(store.runtime.metrics.xp).toBeGreaterThan(0);
  });
});

describe('skill catalog', () => {
  it('merges installed and draft skills and reads local descriptions', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'openclaw-world-skills-'));
    const installedDir = path.join(root, 'installed');
    const reserveDir = path.join(root, 'reserve');
    fs.mkdirSync(installedDir, { recursive: true });
    fs.mkdirSync(reserveDir, { recursive: true });

    fs.mkdirSync(path.join(installedDir, 'agentmail'));
    fs.writeFileSync(
      path.join(installedDir, 'agentmail', 'SKILL.md'),
      '---\ndescription: "Send and manage mail."\n---\n',
    );

    fs.mkdirSync(path.join(reserveDir, 'shell'));
    fs.writeFileSync(
      path.join(reserveDir, 'shell', 'SKILL.md'),
      '# shell\nUse terminal commands safely.\n',
    );

    const result = collectSkillCatalog(
      {
        roleId: 'warrior',
        draftDirty: false,
        identity: {
          assistantName: 'Clawd',
          userName: '主人',
          region: '中国大陆',
          timezone: 'Asia/Shanghai',
          goal: '工程交付',
          personality: '严谨',
          workStyle: '先分析后执行',
        },
        routing: {
          modelRoute: 'codex',
          tokenRule: 'medium',
          skillPack: 'medium',
          advancedModel: 'gpt-5.4',
        },
        skills: {
          installed: ['agentmail', 'shell'],
          disabled: [],
          reserve: [],
        },
        equipment: {
          slots: {},
          inventory: [],
        },
        updatedAt: new Date().toISOString(),
      },
      {
        installedSkillsDir: installedDir,
        reserveSkillsDir: reserveDir,
      },
    );

    expect(result.installed.map((item) => item.id)).toEqual(['agentmail', 'shell']);
    expect(result.installed.find((item) => item.id === 'agentmail')?.description).toContain('Send and manage mail');
    expect(result.installed.find((item) => item.id === 'shell')?.description).toContain('Use terminal commands safely');
    expect(result.reserve).toEqual([]);
  });
});
