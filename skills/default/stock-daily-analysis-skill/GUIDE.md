# Stock Daily Analysis 使用指南

## 1. 功能定位
- 生成 A 股、港股、美股的每日技术面分析与 AI 决策建议。
- 适合做自选股复盘、批量技术面打分、盘后日报。
- 安装形态: 增强技能，按需手动安装
- 仓库目录: `skills/default/stock-daily-analysis-skill`
- 安装后目录: `~/.openclaw/skills/stock-daily-analysis-skill`

## 2. 使用前准备
- Python 3
- 依赖安装: `pip install -r skills/default/stock-daily-analysis-skill/requirements.txt`
- 需要配置一个 OpenAI 兼容模型接口，常见可用 DeepSeek / OpenAI / Gemini 兼容网关

## 3. 配置步骤
1. 复制配置模板:
```bash
cp skills/default/stock-daily-analysis-skill/config.example.json \
   skills/default/stock-daily-analysis-skill/config.json
```
2. 编辑 `config.json`，填写模型提供方、Base URL、模型名和 API Key。
3. 如果要接入更稳定的行情源，可按上游说明联动 `market-data` 类技能。

## 4. 推荐提问方式
- 请用 stock-daily-analysis-skill 分析 600519 今天的技术面。
- 请用 stock-daily-analysis-skill 批量分析 `600036, 000001, AAPL` 并给出买卖建议。

## 5. 手动验证
```bash
cd skills/default/stock-daily-analysis-skill
python3 scripts/analyzer.py 600519
```

## 6. 参考资料
- 上游来源: https://github.com/chjm-ai/stock-daily-analysis-skill
- 本技能说明: `SKILL.md`

## 7. 注意事项
- 该技能会输出买卖建议，但只应作为研究辅助，不应直接视为投资建议。
- `config.json` 含密钥，不要提交到代码仓库。
