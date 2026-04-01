# `minimax-pdf` 使用指南

## 作用
- MiniMax 官方 PDF 处理能力。
- 支持三类流程：新建 PDF、填写 PDF 表单、重排/重设计已有文档。

## 常用命令
- 生成：`bash scripts/make.sh run ...`
- 填表：`python3 scripts/fill_inspect.py` + `python3 scripts/fill_write.py`
- 重排：`bash scripts/make.sh reformat ...`

## 快速示例
```bash
bash skills/default/minimax-pdf/scripts/make.sh run \
  --title "OpenClaw Weekly Report" \
  --type report \
  --out report.pdf
```

