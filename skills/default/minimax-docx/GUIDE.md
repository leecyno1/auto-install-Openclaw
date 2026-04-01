# `minimax-docx` 使用指南

## 作用
- MiniMax 官方 DOCX 技能。
- 支持创建、编辑、套模板/格式化 Word 文档。

## 前置条件
- 首次执行：`bash scripts/setup.sh`
- 每次会话首个任务建议先跑：`scripts/env_check.sh`

## 常见流程
- 创建文档：`dotnet run --project scripts/dotnet/MiniMaxAIDocx.Cli -- create ...`
- 编辑替换：`... -- edit replace-text ...`
- 套模板：`... -- apply-template ...`
- 校验：`... -- validate ...`

## 快速示例
```bash
dotnet run --project skills/default/minimax-docx/scripts/dotnet/MiniMaxAIDocx.Cli -- \
  create --type report --title "OpenClaw Roadmap" --output roadmap.docx
```

