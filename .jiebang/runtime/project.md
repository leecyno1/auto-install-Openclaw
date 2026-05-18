# Project Context

## Goal

维护 `OpenClawInstaller` 的安装、配置、技能集成与可视化入口，确保 OpenClaw / Hermes 双轨安装、技能共享、流量与模型规则、像素小屋前端和配置脚本能够稳定交付并可在真实服务器上运行。

## Scope

In scope:
- 安装脚本、配置菜单、服务启动链路
- 本地 skills 仓库与默认/增强技能包管理
- OpenClaw / Hermes 配置、模型路由、API 与配额规则
- 像素小屋与相关前端配置页面
- 运行时健康检查、桥接与状态读取

Out of scope:
- 与当前任务无关的历史实验分支清理
- 未明确要求的美术资源大规模重绘
- 依赖私有聊天记忆的跨代理交接

## Constraints

- 主仓库路径：`/Volumes/PSSD/Projects/OpenClawInstaller`
- 入口以 shell 脚本、Python、前端子项目混合实现
- 用户要求直接执行，不做空转式方案输出
- 当前仓库是脏工作区，不能回滚未授权改动
- 需要支持低资源机器，避免引入不必要的重型运行时
