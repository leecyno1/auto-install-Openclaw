# OpenClaw World

独立实验项目，用于替代现有像素小屋的长期运行时形态。

## 当前目标

第一阶段只做一个可用闭环，不做兼容负担：

- `Home Base`：单龙虾基地
- `Shared World`：公共世界入口壳
- 支持草稿构筑、应用到 OpenClaw、派发任务、运行时反馈

## 目录结构

- `client/`：Phaser 3 + Vite 前端世界
- `gateway/`：Node HTTP + WebSocket 轻量网关
- `shared/`：前后端共享状态模型
- `data/`：本地 build/runtime/task/world 持久化
- `scripts/dev.sh`：本地双进程开发脚本

## 端口

- `19200`：网关 + 生产构建后的前端
- `19201`：前端开发服务器

## 环境变量

- `OPENCLAW_WORLD_PORT`：网关监听端口，默认 `19200`
- `OPENCLAW_WORLD_HOST`：网关监听地址，默认 `127.0.0.1`
- `OPENCLAW_WORLD_DATA_DIR`：本地状态目录，默认 `subprojects/openclaw-world/data`
- `OPENCLAW_STATUS_URL`：读取 OpenClaw 运行状态的地址，默认 `http://127.0.0.1:13145/status`
- `OPENCLAW_WORLD_TASK_COMMAND`：可选。派单时执行的命令；若未配置，则使用本地模拟执行

## 命令

```bash
cd subprojects/openclaw-world
npm install
npm test
npm run build
npm start
```

本地开发：

```bash
cd subprojects/openclaw-world
./scripts/dev.sh
```

## 当前已实现

- Home Base 六个对象：职业台、技能书架、装备工坊、任务桌、状态镜、世界传送门
- 构筑草稿保存与 `apply` 应用
- 技能目录读取本地技能仓与已装技能目录
- 装备/模型/API/MCP/工具的草稿式切换
- 派单后角色在基地内工位移动，状态通过 WebSocket 回流
- Shared World 入口壳场景
- OpenClaw 缺席时的本地 mirror 模式

## 验证

```bash
cd subprojects/openclaw-world
npm test
npm run build
npm start
```
