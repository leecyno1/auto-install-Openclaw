# Decision Log

## Frozen Decisions

- `lobster-setup` 作为主入口，`openclaw-setup` 仅保留兼容别名，因为文档、测试和安装路径已经围绕前者收口。
- 像素小屋安装/修复时自动接入健康服务与配额服务，因为用户需要安装后即具备可观测性和流量约束。
- 自定义 provider URL 保持用户输入原样，不自动追加 `/anthropic`，因为此前自动改写已造成配置错误。
- 跨代理状态使用 `.jiebang/runtime/` 共享，而不是写回根级说明文件，因为动态进度不应污染稳定指令文件。

## Deferred Decisions

- 是否默认启动 `jiebang` autosave 守护进程，待用户明确要求 `自动交棒` 时再启用。
- 是否把 `.jiebang` 运行文件提交进仓库，待用户确定协作模式后再决定。
