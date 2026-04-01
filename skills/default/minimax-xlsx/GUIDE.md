# `minimax-xlsx` 使用指南

## 作用
- MiniMax 官方表格技能，处理 `.xlsx/.xlsm/.csv/.tsv`。
- 支持读取分析、创建新表、编辑现有表、公式修复与校验。

## 核心原则
- 新建可用模板方式。
- 编辑现有文件优先走 XML 解包/回包流程，避免格式丢失。
- 涉及计算必须优先写公式而非硬编码数值。

## 常用命令
```bash
python3 skills/default/minimax-xlsx/scripts/xlsx_reader.py input.xlsx
python3 skills/default/minimax-xlsx/scripts/xlsx_unpack.py input.xlsx /tmp/xlsx_work
python3 skills/default/minimax-xlsx/scripts/xlsx_pack.py /tmp/xlsx_work output.xlsx
python3 skills/default/minimax-xlsx/scripts/formula_check.py output.xlsx --report
```

