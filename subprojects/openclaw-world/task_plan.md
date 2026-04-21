# OpenClaw World Task Plan

## Goal
实现独立实验项目第一阶段 MVP：`Home Base + Shared World shell`，形成“配置草稿 -> 应用到 OpenClaw -> 派发任务 -> 世界内反馈”的可运行闭环。

## Phases
- [completed] P1 盘点现状并补齐设计/计划文件
- [completed] P2 重构前端控制台布局，使 Home Base 的六个对象都形成稳定的操作面板
- [completed] P3 增强世界渲染与运行态反馈，让人物/工位/场景切换更直观
- [completed] P4 补齐后端状态域与接口边界，确保草稿/应用/派单流程自洽
- [completed] P5 增加测试与运行脚本，完成验证

## Constraints
- 不触碰旧像素小屋逻辑
- 不覆盖用户现有 OpenClaw 记忆/对话数据
- 保持 2C2G 约束下的轻量实现
- 第一阶段 Shared World 只做入口壳，不做多人同步

## Risks
- Phaser 首屏可见性与交互同步可能有 race condition
- 本地技能仓很多，技能列表渲染需要限制成本
- OpenClaw CLI 可能不存在，只能走本地镜像模式

## Errors Encountered
- 暂无
