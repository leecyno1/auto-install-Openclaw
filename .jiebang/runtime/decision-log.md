# Decision Log

## Frozen Decisions

- `openclaw-setup` 作为主入口，`lobster-setup` 仅保留兼容别名，因为 README、安装提示和入口脚本已围绕前者收口。
- 像素小屋安装/修复时默认自动接入 13146 健康服务；13147 兼容配额代理仅在显式启用时启动，避免新安装默认走旧限流入口。
- 自定义 provider URL 保持用户输入原样，不自动追加 `/anthropic`，因为此前自动改写已造成配置错误。
- 跨代理状态使用 `.jiebang/runtime/` 共享，而不是写回根级说明文件，因为动态进度不应污染稳定指令文件。

## Deferred Decisions

- 是否默认启动 `jiebang` autosave 守护进程，待用户明确要求 `自动交棒` 时再启用。
- 是否把 `.jiebang` 运行文件提交进仓库，待用户确定协作模式后再决定。
