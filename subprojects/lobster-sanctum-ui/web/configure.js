const defaultRole = "druid";
const stateKey = "openclaw.command.center";
const HOTBAR_SIZE = 6;
const SLOT_ORDER = ["head", "shoulders", "core", "mainhand", "offhand", "relic", "network", "companion", "automation", "belt", "boots", "ring"];

const roleProfiles = {
  druid: {
    className: "通用总管",
    title: "万金油 · 德鲁伊",
    desc: "综合协同、日程编排、搜索整理和任务跟进的稳定人格。",
    image: "./assets/role-druid.png",
    portraitPosition: "center 18%",
    tags: ["综合协同", "主动巡航", "长期陪跑"],
    specialty: "综合协同",
    taskFocus: ["日程管理", "邮件草拟", "综合搜索", "资料整理"],
  },
  assassin: {
    className: "投资分析",
    title: "分析员 · 刺客",
    desc: "市场、财报、行业与估值框架的深度分析人格。",
    image: "./assets/role-assassin.png",
    portraitPosition: "center 20%",
    tags: ["机会扫描", "估值解剖", "风险捕捉"],
    specialty: "情报分析",
    taskFocus: ["公司调研", "行业研究", "估值比较", "风险跟踪"],
  },
  mage: {
    className: "研究学习",
    title: "研究者 · 大法师",
    desc: "论文、读书、证据链与研究综述的知识型人格。",
    image: "./assets/role-mage.png",
    portraitPosition: "center 16%",
    tags: ["知识归纳", "文献整理", "长上下文"],
    specialty: "研究整理",
    taskFocus: ["论文阅读", "综述写作", "笔记沉淀", "研究设计"],
  },
  summoner: {
    className: "组织管理",
    title: "管理者 · 召唤师",
    desc: "招聘、流程、会议纪要、项目推进的管理型人格。",
    image: "./assets/role-summoner.png",
    portraitPosition: "center 18%",
    tags: ["组织编排", "例会纪要", "多人协同"],
    specialty: "流程治理",
    taskFocus: ["招聘管理", "项目推进", "制度输出", "团队复盘"],
  },
  warrior: {
    className: "工程开发",
    title: "技术员 · 战士",
    desc: "开发交付、测试排障、自动化和浏览器调试人格。",
    image: "./assets/role-warrior.png",
    portraitPosition: "center 18%",
    tags: ["工程交付", "自动验证", "问题歼灭"],
    specialty: "代码执行",
    taskFocus: ["代码修改", "测试排障", "浏览器调试", "自动化脚本"],
  },
  paladin: {
    className: "增长运营",
    title: "营销者 · 圣骑士",
    desc: "内容增长、SEO、投放复盘和客户沟通人格。",
    image: "./assets/role-paladin.png",
    portraitPosition: "center 18%",
    tags: ["内容引擎", "增长推进", "客户沟通"],
    specialty: "增长转化",
    taskFocus: ["内容运营", "渠道分析", "营销策划", "客户沟通"],
  },
  archer: {
    className: "设计创意",
    title: "设计师 · 弓箭手",
    desc: "UI、图像、KV、视频分镜与创意表达人格。",
    image: "./assets/role-archer.png",
    portraitPosition: "center 18%",
    tags: ["视觉创作", "界面塑形", "图像召唤"],
    specialty: "视觉构图",
    taskFocus: ["UI 设计", "海报 KV", "图像生成", "视频分镜"],
  },
};

const packageDefs = [
  { id: "low", label: "低档默认包", note: "基础执行力，优先装控制、搜索、文档和金融核心技能。" },
  { id: "medium", label: "中档增强包", note: "在低档基础上补足邮件、总结、内容与图像能力。" },
  { id: "high", label: "高档超级包", note: "解锁视频、设计、营销、分发和高阶创作能力。" },
];

const tokenRules = [
  { id: "none", label: "跳过注入", note: "不写入 token 规划规则。" },
  { id: "low", label: "低档规则", note: "10 小时 / 100 次，请求稳定保守。" },
  { id: "medium", label: "中档规则", note: "10 小时 / 200 次，平衡响应和任务复杂度。" },
  { id: "high", label: "高档规则", note: "10 小时 / 300 次，适合高频与复杂任务。" },
];

const modelRoutes = [
  { id: "balanced", label: "均衡协作路由", note: "Claude / GPT 协同，综合任务稳定。" },
  { id: "analysis", label: "深度分析路由", note: "适合研究、估值、长文本判断。" },
  { id: "research", label: "研究长文路由", note: "适合论文、笔记、长上下文。" },
  { id: "codex", label: "工程交付路由", note: "适合代码实现、调试、验证。" },
  { id: "growth", label: "增长运营路由", note: "适合内容策略、投放与渠道。" },
  { id: "creative", label: "创意生成路由", note: "适合 UI、图像和视频构图。" },
];

const securityOptions = [
  { id: "system", label: "系统权限保护", note: "限制危险系统调用边界。" },
  { id: "file", label: "文件访问保护", note: "保护敏感目录与配置文件。" },
  { id: "web", label: "网页访问保护", note: "避免越权抓取和敏感外发。" },
  { id: "session", label: "会话记忆保护", note: "控制历史数据暴露与引用。" },
  { id: "tools", label: "工具调用保护", note: "限制非常规工具串联。" },
];

const slotLabels = {
  head: "头部",
  shoulders: "肩甲",
  core: "核心",
  mainhand: "主手",
  offhand: "副手",
  relic: "圣物",
  network: "网络",
  companion: "伴随",
  automation: "自动化",
  belt: "腰带",
  boots: "靴位",
  ring: "戒位",
};

const branchMeta = {
  控制中枢: { short: "中枢", note: "控制规则、主动巡航与反思注入。", accent: "蓝印" },
  执行系统: { short: "执行", note: "代码、浏览器与工程执行链。", accent: "铁匠" },
  情报网络: { short: "情报", note: "搜索、抓取、热点与情报聚合。", accent: "侦查" },
  知识文档: { short: "文档", note: "文档、笔记、摘要与资料沉淀。", accent: "档案" },
  金融引擎: { short: "金融", note: "市场雷达、财报与估值框架。", accent: "量化" },
  增长工坊: { short: "增长", note: "内容、分发、转化与渠道运营。", accent: "增长" },
  创意工坊: { short: "创意", note: "UI、图像、视频与视觉生成。", accent: "造物" },
  视觉理解: { short: "视觉", note: "识图、审图与多模态观察。", accent: "感知" },
};

const skillFilters = [
  { id: "all", label: "全部技能" },
  { id: "installed", label: "已安装" },
  { id: "recommended", label: "推荐构筑" },
  { id: "unlockable", label: "当前可装" },
  { id: "hotbar", label: "工作栏" },
];

const inventoryFilters = [
  { id: "all", label: "全部" },
  { id: "equipped", label: "已装备" },
  { id: "模型", label: "模型" },
  { id: "MCP", label: "MCP" },
  { id: "Tool", label: "Tool" },
  { id: "App", label: "App" },
  { id: "API", label: "API" },
];

const skillCatalog = [
  { id: "capability-evolver", name: "Capability Evolver", tier: "low", branch: "控制中枢", desc: "基于历史运行数据做能力进化与策略优化。", deps: [], roles: ["druid", "summoner"], pack: ["low", "medium", "high"] },
  { id: "openclaw-cron-setup", name: "Cron Setup", tier: "low", branch: "控制中枢", desc: "定时唤醒与主动任务执行框架。", deps: [], roles: ["druid", "summoner", "warrior"], pack: ["low", "medium", "high"] },
  { id: "proactive-agent", name: "Proactive Agent", tier: "low", branch: "控制中枢", desc: "让 Agent 主动跟进而非被动等待。", deps: [], roles: ["druid", "summoner"], pack: ["low", "medium", "high"] },
  { id: "self-improving-agent-cn", name: "Self Improving CN", tier: "low", branch: "控制中枢", desc: "自我反思、自我纠错并沉淀改进。", deps: ["reflection"], roles: ["druid", "mage"], pack: ["low", "medium", "high"] },
  { id: "brainstorming", name: "Brainstorming", tier: "low", branch: "控制中枢", desc: "创意任务前的澄清与发散。", deps: [], roles: ["mage", "paladin", "archer"], pack: ["low", "medium", "high"] },
  { id: "reflection", name: "Reflection", tier: "low", branch: "控制中枢", desc: "对对话、任务和工具使用做复盘。", deps: [], roles: ["druid", "mage", "summoner"], pack: ["low", "medium", "high"] },
  { id: "find-skills", name: "Find Skills", tier: "low", branch: "控制中枢", desc: "按需求搜索并推荐可安装技能。", deps: ["web-search"], roles: ["druid"], pack: ["low", "medium", "high"] },
  { id: "skill-creator", name: "Skill Creator", tier: "low", branch: "控制中枢", desc: "创建新的 Skill 模板和说明。", deps: ["find-skills"], roles: ["warrior", "mage"], pack: ["low", "medium", "high"] },

  { id: "agent-browser", name: "Agent Browser", tier: "low", branch: "执行系统", desc: "自动化浏览器交互与页面操作。", deps: [], roles: ["warrior", "archer"], pack: ["low", "medium", "high"] },
  { id: "chrome-devtools-mcp", name: "Chrome DevTools MCP", tier: "low", branch: "执行系统", desc: "浏览器调试、网络与性能分析。", deps: ["agent-browser"], roles: ["warrior", "archer"], pack: ["low", "medium", "high"] },
  { id: "github", name: "GitHub", tier: "low", branch: "执行系统", desc: "仓库读写与协作。", deps: [], roles: ["warrior", "summoner"], pack: ["low", "medium", "high"] },
  { id: "mcp-builder", name: "MCP Builder", tier: "low", branch: "执行系统", desc: "构建 MCP 服务与协议工具。", deps: ["github"], roles: ["warrior"], pack: ["low", "medium", "high"] },
  { id: "model-usage", name: "Model Usage", tier: "low", branch: "执行系统", desc: "模型调用统计与用量观察。", deps: [], roles: ["warrior", "druid"], pack: ["low", "medium", "high"] },
  { id: "shell", name: "Shell", tier: "low", branch: "执行系统", desc: "脚本执行、进程与文件操作。", deps: [], roles: ["warrior", "druid"], pack: ["low", "medium", "high"] },

  { id: "web-search", name: "Web Search", tier: "low", branch: "情报网络", desc: "通用网页搜索。", deps: [], roles: ["assassin", "paladin", "druid"], pack: ["low", "medium", "high"] },
  { id: "tavily-search", name: "Tavily Search", tier: "low", branch: "情报网络", desc: "LLM 优化搜索。", deps: ["web-search"], roles: ["assassin", "mage"], pack: ["low", "medium", "high"] },
  { id: "minimax-web-search", name: "MiniMax Web Search", tier: "low", branch: "情报网络", desc: "MiniMax 搜索链路。", deps: ["web-search"], roles: ["druid", "assassin"], pack: ["low", "medium", "high"] },
  { id: "news-radar", name: "News Radar", tier: "low", branch: "情报网络", desc: "新闻聚合与热点跟踪。", deps: ["web-search"], roles: ["assassin", "paladin"], pack: ["low", "medium", "high"] },
  { id: "url-to-markdown", name: "URL To Markdown", tier: "low", branch: "情报网络", desc: "网页转 Markdown 供后续处理。", deps: ["web-search"], roles: ["mage", "druid"], pack: ["low", "medium", "high"] },
  { id: "blogwatcher", name: "Blogwatcher", tier: "medium", branch: "情报网络", desc: "订阅追踪博客与内容源。", deps: ["news-radar"], roles: ["paladin", "druid"], pack: ["medium", "high"] },

  { id: "pdf", name: "PDF", tier: "low", branch: "知识文档", desc: "PDF 解析、合并、表单处理。", deps: [], roles: ["mage", "summoner"], pack: ["low", "medium", "high"] },
  { id: "nano-pdf", name: "Nano PDF", tier: "medium", branch: "知识文档", desc: "快速抽取 PDF 摘要与要点。", deps: ["pdf"], roles: ["mage"], pack: ["medium", "high"] },
  { id: "docx", name: "Docx", tier: "low", branch: "知识文档", desc: "Word 创建、编辑与批注。", deps: [], roles: ["summoner", "paladin"], pack: ["low", "medium", "high"] },
  { id: "pptx", name: "PPTX", tier: "low", branch: "知识文档", desc: "PPT 生成与展示材料。", deps: ["docx"], roles: ["summoner", "paladin", "archer"], pack: ["low", "medium", "high"] },
  { id: "xlsx", name: "XLSX", tier: "low", branch: "知识文档", desc: "表格读写、分析与公式处理。", deps: [], roles: ["assassin", "summoner"], pack: ["low", "medium", "high"] },
  { id: "summarize", name: "Summarize", tier: "medium", branch: "知识文档", desc: "长文压缩与结构化摘要。", deps: ["url-to-markdown"], roles: ["mage", "druid"], pack: ["medium", "high"] },
  { id: "notebooklm-skill", name: "NotebookLM", tier: "medium", branch: "知识文档", desc: "与 NotebookLM 笔记库交互。", deps: ["pdf", "summarize"], roles: ["mage"], pack: ["medium", "high"] },
  { id: "agentmail", name: "AgentMail", tier: "medium", branch: "知识文档", desc: "邮件草拟与收发工作流。", deps: ["docx"], roles: ["druid", "paladin", "summoner"], pack: ["medium", "high"] },

  { id: "stock-monitor-skill", name: "Stock Monitor", tier: "low", branch: "金融引擎", desc: "个股盯盘与异动提醒。", deps: [], roles: ["assassin"], pack: ["low", "medium", "high"] },
  { id: "multi-search-engine", name: "Multi Search Engine", tier: "low", branch: "金融引擎", desc: "多引擎联合搜索。", deps: ["web-search", "tavily-search"], roles: ["assassin"], pack: ["low", "medium", "high"] },
  { id: "akshare-stock", name: "AkShare Stock", tier: "low", branch: "金融引擎", desc: "证券数据抓取与财务读取。", deps: ["xlsx"], roles: ["assassin"], pack: ["low", "medium", "high"] },

  { id: "content-strategy", name: "Content Strategy", tier: "medium", branch: "增长工坊", desc: "内容策略、选题与规划。", deps: ["summarize", "web-search"], roles: ["paladin"], pack: ["medium", "high"] },
  { id: "social-content", name: "Social Content", tier: "medium", branch: "增长工坊", desc: "社媒内容拆分与发布策略。", deps: ["content-strategy"], roles: ["paladin"], pack: ["medium", "high"] },
  { id: "marketingskills", name: "Marketing Skills", tier: "high", branch: "增长工坊", desc: "市场内容与分发工具集。", deps: ["content-strategy", "social-content"], roles: ["paladin"], pack: ["high"] },
  { id: "baoyu-skills", name: "Baoyu Skills", tier: "high", branch: "增长工坊", desc: "内容产出与跨平台分发。", deps: ["social-content"], roles: ["paladin", "archer"], pack: ["high"] },

  { id: "frontend-design", name: "Frontend Design", tier: "high", branch: "创意工坊", desc: "高质量前端界面设计实现。", deps: [], roles: ["archer", "warrior"], pack: ["high"] },
  { id: "web-design", name: "Web Design", tier: "high", branch: "创意工坊", desc: "UI / 可用性审查。", deps: ["frontend-design"], roles: ["archer"], pack: ["high"] },
  { id: "ai-image-generation", name: "AI Image Generation", tier: "medium", branch: "创意工坊", desc: "多模型图像生成入口。", deps: [], roles: ["archer"], pack: ["medium", "high"] },
  { id: "gemini-image-service", name: "Gemini Image Service", tier: "medium", branch: "创意工坊", desc: "Gemini 图像理解与生成。", deps: ["ai-image-generation"], roles: ["archer"], pack: ["medium", "high"] },
  { id: "nano-banana-service", name: "Nano Banana Service", tier: "medium", branch: "创意工坊", desc: "Nano Banana 图像创作服务。", deps: ["ai-image-generation"], roles: ["archer"], pack: ["medium", "high"] },
  { id: "grok-imagine-1.0-video", name: "Grok Imagine Video", tier: "high", branch: "创意工坊", desc: "视频生成与镜头表达。", deps: ["gemini-image-service", "nano-banana-service"], roles: ["archer"], pack: ["high"] },
  { id: "inference-skills", name: "Inference Skills", tier: "high", branch: "创意工坊", desc: "Inference 通用图像与创意能力集。", deps: ["ai-image-generation"], roles: ["archer"], pack: ["high"] },

  { id: "minimax-understand-image", name: "MiniMax Understand Image", tier: "low", branch: "视觉理解", desc: "图像理解分析。", deps: [], roles: ["archer", "warrior"], pack: ["low", "medium", "high"] },
];

const toolCatalog = [
  { id: "claude-main", name: "Claude Main", type: "模型", rarity: "mythic", slot: "head", desc: "长文本、规划与复杂推理。", roles: ["druid", "assassin", "mage", "summoner", "paladin"] },
  { id: "codex-core", name: "Codex Core", type: "模型", rarity: "mythic", slot: "head", desc: "代码实现、调试与验证。", roles: ["warrior"] },
  { id: "gemini-vision", name: "Gemini Vision", type: "模型", rarity: "mythic", slot: "head", desc: "多模态理解与图像任务。", roles: ["archer", "mage", "paladin"] },
  { id: "nano-banana", name: "Nano Banana", type: "模型", rarity: "rare", slot: "head", desc: "视觉创作与人物图生成。", roles: ["archer"] },
  { id: "focus-crown", name: "Focus Crown", type: "App", rarity: "magic", slot: "shoulders", desc: "集中上下文和任务优先级。", roles: ["druid", "mage", "summoner"] },
  { id: "ops-harness", name: "Ops Harness", type: "Tool", rarity: "rare", slot: "shoulders", desc: "稳定任务分派和组织调度。", roles: ["summoner", "warrior"] },
  { id: "router-glyph", name: "Model Router Glyph", type: "Tool", rarity: "rare", slot: "core", desc: "模型自动切换路由。", roles: ["druid", "warrior", "archer"] },
  { id: "reflection-seal", name: "Reflection Seal", type: "Tool", rarity: "magic", slot: "core", desc: "复盘、自纠与规则注入。", roles: ["druid", "mage", "summoner"] },
  { id: "notebook-vault", name: "Notebook Vault", type: "App", rarity: "rare", slot: "core", desc: "研究笔记和知识库联动。", roles: ["mage"] },
  { id: "chrome-devtools", name: "Chrome DevTools", type: "MCP", rarity: "rare", slot: "mainhand", desc: "页面调试与网络分析。", roles: ["warrior", "archer"] },
  { id: "agent-browser-rig", name: "Agent Browser Rig", type: "Tool", rarity: "magic", slot: "mainhand", desc: "浏览器自动化和任务流。", roles: ["warrior", "archer"] },
  { id: "shell-runner", name: "Shell Runner", type: "Tool", rarity: "common", slot: "mainhand", desc: "命令行、脚本和文件操作。", roles: ["warrior", "druid"] },
  { id: "github-mcp", name: "GitHub MCP", type: "MCP", rarity: "rare", slot: "offhand", desc: "仓库读写与协同。", roles: ["warrior", "summoner"] },
  { id: "image-studio", name: "Image Studio", type: "Tool", rarity: "rare", slot: "offhand", desc: "图像生成与补图。", roles: ["archer"] },
  { id: "document-forge", name: "Document Forge", type: "Tool", rarity: "magic", slot: "relic", desc: "Docx / PDF / PPTX 输出。", roles: ["mage", "summoner", "paladin"] },
  { id: "sheet-engine", name: "Sheet Engine", type: "Tool", rarity: "magic", slot: "relic", desc: "XLSX 分析与表格建模。", roles: ["assassin", "summoner"] },
  { id: "search-array", name: "Search Array", type: "API", rarity: "magic", slot: "network", desc: "搜索 API 聚合阵列。", roles: ["druid", "assassin", "paladin"] },
  { id: "tavily-core", name: "Tavily Core", type: "API", rarity: "magic", slot: "network", desc: "结构化外部搜索接口。", roles: ["assassin", "mage"] },
  { id: "market-radar", name: "Market Radar", type: "API", rarity: "rare", slot: "network", desc: "新闻雷达与市场情报。", roles: ["assassin", "paladin"] },
  { id: "agentmail-suite", name: "AgentMail Suite", type: "App", rarity: "magic", slot: "companion", desc: "邮件往来与客户沟通。", roles: ["druid", "paladin", "summoner"] },
  { id: "video-anvil", name: "Video Anvil", type: "Tool", rarity: "rare", slot: "companion", desc: "视频分镜与成片链路。", roles: ["archer"] },
  { id: "cron-orb", name: "Cron Orb", type: "Tool", rarity: "rare", slot: "automation", desc: "定时任务与后台巡检。", roles: ["druid", "summoner", "warrior"] },
  { id: "watchtower-daemon", name: "Watchtower Daemon", type: "Tool", rarity: "magic", slot: "automation", desc: "心跳巡检与异常恢复。", roles: ["druid", "warrior"] },
  { id: "utility-belt", name: "Utility Belt", type: "Tool", rarity: "common", slot: "belt", desc: "整理高频工具与快捷命令。", roles: ["druid", "warrior", "summoner"] },
  { id: "campaign-belt", name: "Campaign Belt", type: "App", rarity: "magic", slot: "belt", desc: "渠道分发、营销节奏和触达配置。", roles: ["paladin"] },
  { id: "field-boots", name: "Field Boots", type: "Tool", rarity: "common", slot: "boots", desc: "提高情报巡航和执行节奏。", roles: ["assassin", "warrior", "druid"] },
  { id: "atelier-boots", name: "Atelier Boots", type: "Tool", rarity: "magic", slot: "boots", desc: "提高创意流转和素材整合效率。", roles: ["archer"] },
  { id: "signal-ring", name: "Signal Ring", type: "API", rarity: "rare", slot: "ring", desc: "将外部接口与角色核心建立联动。", roles: ["druid", "warrior", "archer", "assassin"] },
  { id: "memo-ring", name: "Memo Ring", type: "App", rarity: "magic", slot: "ring", desc: "记忆、注释和上下文收纳。", roles: ["mage", "summoner"] },
];

const synergies = [
  {
    id: "autopilot-loop",
    name: "主动巡航回路",
    note: "让角色持续巡检、汇报、纠偏，适合作为默认值班形态。",
    skills: ["proactive-agent", "openclaw-cron-setup", "reflection"],
    tools: ["cron-orb", "reflection-seal"],
  },
  {
    id: "research-vault",
    name: "研究注释链",
    note: "将材料、PDF、摘要和知识库统一串联，适合论文与学习场景。",
    skills: ["pdf", "summarize", "notebooklm-skill"],
    tools: ["notebook-vault", "document-forge"],
  },
  {
    id: "quant-sentinel",
    name: "量化哨塔",
    note: "市场数据、新闻与表格建模打通，适合投资分析。",
    skills: ["stock-monitor-skill", "akshare-stock", "multi-search-engine"],
    tools: ["market-radar", "sheet-engine"],
  },
  {
    id: "creative-forge",
    name: "视觉工坊",
    note: "UI、图像与视频联动，适合设计师和内容团队。",
    skills: ["frontend-design", "gemini-image-service", "nano-banana-service"],
    tools: ["image-studio", "video-anvil"],
  },
  {
    id: "ops-broadcast",
    name: "分发矩阵",
    note: "内容策略、社媒分发和邮件触达串成统一输出链。",
    skills: ["content-strategy", "social-content", "baoyu-skills"],
    tools: ["agentmail-suite"],
  },
  {
    id: "engineering-smelter",
    name: "工程熔炉",
    note: "代码实现、浏览器调试和仓库协作形成闭环。",
    skills: ["shell", "agent-browser", "chrome-devtools-mcp"],
    tools: ["codex-core", "chrome-devtools", "github-mcp"],
  },
  {
    id: "routing-core",
    name: "多模型中枢",
    note: "模型路由和用量观察形成动态切换中台。",
    skills: ["model-usage", "capability-evolver"],
    tools: ["router-glyph", "claude-main"],
  },
  {
    id: "debug-console",
    name: "远程工程台",
    note: "Codex、DevTools 和仓库协作形成远程工程控制台。",
    skills: [],
    tools: ["codex-core", "chrome-devtools", "github-mcp"],
  },
  {
    id: "design-console",
    name: "设计中台",
    note: "Gemini、Nano Banana 与图像工坊形成视觉生成闭环。",
    skills: [],
    tools: ["gemini-vision", "nano-banana", "image-studio"],
  },
  {
    id: "intel-console",
    name: "情报总线",
    note: "搜索聚合、市场雷达与表格引擎形成高频情报站。",
    skills: [],
    tools: ["search-array", "market-radar", "sheet-engine"],
  },
];

function readRole() {
  const params = new URLSearchParams(window.location.search);
  return params.get("role") || window.localStorage.getItem("openclaw.persona.role") || defaultRole;
}

function readRequestedTab() {
  const params = new URLSearchParams(window.location.search);
  const tab = params.get("tab");
  return ["skills", "equipment", "status", "tasks", "levels"].includes(tab) ? tab : null;
}

function loadStore() {
  try {
    return JSON.parse(window.localStorage.getItem(stateKey) || "{}");
  } catch {
    return {};
  }
}

function saveStore(data) {
  window.localStorage.setItem(stateKey, JSON.stringify(data));
}

function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

function packageIndex(id) {
  return packageDefs.findIndex((item) => item.id === id);
}

function skillById(id) {
  return skillCatalog.find((item) => item.id === id);
}

function toolById(id) {
  return toolCatalog.find((item) => item.id === id);
}

function roleDefaultSkills(role, skillPack) {
  const maxIndex = packageIndex(skillPack);
  return skillCatalog
    .filter((skill) => {
      const allowed = skill.pack.some((pack) => packageIndex(pack) <= maxIndex);
      const roleMatch = skill.roles.length === 0 || skill.roles.includes(role);
      return allowed && roleMatch;
    })
    .map((skill) => skill.id);
}

function roleDefaultTools(role) {
  return toolCatalog.filter((tool) => tool.roles.includes(role)).slice(0, 8).map((tool) => tool.id);
}

function recommendedSynergiesForRole(role) {
  const toolIds = new Set(toolCatalog.filter((tool) => tool.roles.includes(role)).map((tool) => tool.id));
  const skillIds = new Set(skillCatalog.filter((skill) => skill.roles.includes(role)).map((skill) => skill.id));
  return synergies.filter((entry) => entry.skills.some((id) => skillIds.has(id)) || entry.tools.some((id) => toolIds.has(id)));
}

function recommendedSkillIds(role) {
  const fromSynergy = recommendedSynergiesForRole(role).flatMap((entry) => entry.skills);
  return Array.from(
    new Set([
      ...roleProfiles[role].taskFocus.flatMap((focus) =>
        skillCatalog.filter((skill) => skill.roles.includes(role) && (skill.desc.includes(focus) || skill.name.includes(focus))).map((skill) => skill.id),
      ),
      ...fromSynergy,
      ...roleDefaultSkills(role, role === "archer" || role === "paladin" ? "high" : "medium").slice(0, 8),
    ]),
  );
}

function recommendedToolIds(role) {
  const fromSynergy = recommendedSynergiesForRole(role).flatMap((entry) => entry.tools);
  return Array.from(new Set([...fromSynergy, ...roleDefaultTools(role)]));
}

function createDefaultState(role) {
  const defaultPack = role === "archer" || role === "paladin" ? "high" : role === "warrior" || role === "assassin" ? "medium" : "medium";
  const installedSkills = roleDefaultSkills(role, defaultPack);
  const defaultHotbar = installedSkills.slice(0, HOTBAR_SIZE);
  const defaultToolIds = roleDefaultTools(role);
  const equipped = {};
  SLOT_ORDER.forEach((slot) => {
    const match = defaultToolIds.map(toolById).find((tool) => tool && tool.slot === slot);
    equipped[slot] = match?.id || null;
  });

  const routeByRole = {
    druid: "balanced",
    assassin: "analysis",
    mage: "research",
    summoner: "balanced",
    warrior: "codex",
    paladin: "growth",
    archer: "creative",
  };

  return {
    activeTab: "skills",
    skillPack: defaultPack,
    tokenRule: role === "warrior" || role === "archer" || role === "assassin" ? "high" : "medium",
    modelRoute: routeByRole[role] || "balanced",
    installedSkills,
    hotbar: Array.from({ length: HOTBAR_SIZE }, (_, index) => defaultHotbar[index] || null),
    pinnedSkills: Array.from({ length: 3 }, (_, index) => defaultHotbar[index] || null),
    equipped,
    inventory: defaultToolIds,
    stash: toolCatalog.filter((tool) => tool.roles.includes(role) && !defaultToolIds.includes(tool.id)).map((tool) => tool.id),
    selectedToolId: defaultToolIds[0] || null,
    selectedSkillId: defaultHotbar[0] || installedSkills[0] || null,
    skillNodeOffsets: {},
    security: ["system", "file", "web", "session"],
    skillFilter: "all",
    branchFocus: "all",
    inventoryFilter: "all",
  };
}

function normalizeRoleState(role, roleState) {
  const base = createDefaultState(role);
  const merged = { ...base, ...roleState };
  merged.hotbar = Array.from({ length: HOTBAR_SIZE }, (_, index) => merged.hotbar?.[index] || null);
  merged.pinnedSkills = Array.from({ length: 3 }, (_, index) => merged.pinnedSkills?.[index] || null);
  merged.equipped = { ...base.equipped, ...(roleState.equipped || {}) };
  merged.inventory = Array.from(new Set((merged.inventory || []).filter((id) => toolById(id))));
  merged.installedSkills = Array.from(new Set((merged.installedSkills || []).filter((id) => skillById(id))));
  merged.security = Array.from(new Set((merged.security || []).filter((id) => securityOptions.some((option) => option.id === id))));
  merged.skillNodeOffsets = merged.skillNodeOffsets || {};
  if (!skillFilters.some((item) => item.id === merged.skillFilter)) merged.skillFilter = "all";
  if (merged.branchFocus !== "all" && !branchMeta[merged.branchFocus]) merged.branchFocus = "all";
  if (!inventoryFilters.some((item) => item.id === merged.inventoryFilter)) merged.inventoryFilter = "all";
  if (!tokenRules.some((item) => item.id === merged.tokenRule)) merged.tokenRule = base.tokenRule;
  if (!packageDefs.some((item) => item.id === merged.skillPack)) merged.skillPack = base.skillPack;
  if (!modelRoutes.some((item) => item.id === merged.modelRoute)) merged.modelRoute = base.modelRoute;
  if (!merged.selectedToolId || !toolById(merged.selectedToolId)) merged.selectedToolId = merged.inventory[0] || base.selectedToolId;
  if (!merged.selectedSkillId || !skillById(merged.selectedSkillId)) merged.selectedSkillId = merged.installedSkills[0] || base.selectedSkillId;
  return merged;
}

function loadRoleState(role) {
  const store = loadStore();
  if (!store[role]) {
    store[role] = createDefaultState(role);
    saveStore(store);
  }
  return normalizeRoleState(role, deepClone(store[role]));
}

function persistRoleState(role, roleState) {
  const store = loadStore();
  store[role] = deepClone(roleState);
  saveStore(store);
}

function optionLabel(list, id) {
  return list.find((item) => item.id === id)?.label || id;
}

function tierChinese(id) {
  if (id === "low") return "低档";
  if (id === "medium") return "中档";
  if (id === "high") return "高档";
  return id;
}

function slotLabel(id) {
  return slotLabels[id] || id;
}

function skillMatchesFilter(skill, roleState, currentPackIndex, recommendedSet) {
  const installed = roleState.installedSkills.includes(skill.id);
  const hotbar = roleState.hotbar.includes(skill.id);
  const unlocked = packageIndex(skill.tier) <= currentPackIndex;
  const depsReady = skill.deps.every((dep) => roleState.installedSkills.includes(dep));
  if (roleState.skillFilter === "installed") return installed;
  if (roleState.skillFilter === "recommended") return recommendedSet.has(skill.id);
  if (roleState.skillFilter === "unlockable") return unlocked && depsReady;
  if (roleState.skillFilter === "hotbar") return hotbar;
  return true;
}

function toolMatchesFilter(tool, roleState) {
  if (roleState.inventoryFilter === "all") return true;
  if (roleState.inventoryFilter === "equipped") return Object.values(roleState.equipped).includes(tool.id);
  return tool.type === roleState.inventoryFilter;
}

function rarityScore(rarity) {
  return { common: 1, magic: 2, rare: 3, mythic: 4 }[rarity] || 1;
}

function computePresetPayload(role, roleState) {
  return {
    version: 1,
    generatedAt: new Date().toISOString(),
    persona: {
      id: role,
      title: roleProfiles[role].title,
      className: roleProfiles[role].className,
      goal: roleProfiles[role].taskFocus.join("、"),
    },
    routing: {
      modelRoute: roleState.modelRoute,
      tokenRule: roleState.tokenRule,
      skillPack: roleState.skillPack,
      security: roleState.security,
    },
    loadout: {
      hotbar: roleState.hotbar.filter(Boolean),
      pinnedSkills: roleState.pinnedSkills.filter(Boolean),
      equipped: roleState.equipped,
      inventory: roleState.inventory,
    },
    uiState: {
      branchFocus: roleState.branchFocus,
      skillFilter: roleState.skillFilter,
      inventoryFilter: roleState.inventoryFilter,
      skillNodeOffsets: roleState.skillNodeOffsets,
    },
  };
}

function buildEnvBlock(role, roleState) {
  const lines = [
    `export OPENCLAW_PERSONA_ROLE=${role}`,
    `export OPENCLAW_RULE_PROFILE=${roleState.tokenRule}`,
    `export OPENCLAW_WEB_SKILL_PACK=${roleState.skillPack}`,
    `export OPENCLAW_WEB_MODEL_ROUTE=${roleState.modelRoute}`,
    `export OPENCLAW_WEB_SECURITY="${roleState.security.join(",")}"`,
    `export OPENCLAW_WEB_HOTBAR="${roleState.hotbar.filter(Boolean).join(",")}"`,
    `export OPENCLAW_WEB_PINNED_SKILLS="${roleState.pinnedSkills.filter(Boolean).join(",")}"`,
    `export OPENCLAW_WEB_TOOLS="${Object.values(roleState.equipped).filter(Boolean).join(",")}"`,
  ];
  return lines.join("\n");
}

function buildCommand(role, roleState) {
  return [
    "# 先点击页面右上角“下载配置档案”，保存为 ./openclaw-" + role + "-profile.json",
    buildEnvBlock(role, roleState),
    `bash ./install.sh --persona ${role} --rule-profile ${roleState.tokenRule} --gateway-port 13145`,
    `bash ./scripts/apply-web-profile.sh ./openclaw-${role}-profile.json`,
  ].join("\n");
}

function nodeBasePosition(tier, index, total) {
  const laneIndex = { low: 0, medium: 1, high: 2 }[tier] || 0;
  const x = 48 + laneIndex * 264;
  const verticalGap = total > 1 ? Math.max(118, Math.floor(300 / (total - 1))) : 0;
  const y = 42 + index * verticalGap;
  return { x, y };
}

function nodeStoredOffset(roleState, skillId) {
  return roleState.skillNodeOffsets?.[skillId] || { x: 0, y: 0 };
}

function setActiveTab(roleState, tabId) {
  roleState.activeTab = tabId;
  document.querySelectorAll(".tab-button").forEach((button) => {
    button.classList.toggle("active", button.dataset.tab === tabId);
  });
  document.querySelectorAll(".tab-panel").forEach((panel) => {
    panel.classList.toggle("active", panel.dataset.panel === tabId);
  });
}

function createRadioGroup(target, name, options, selectedId, onChange) {
  target.innerHTML = "";
  options.forEach((option) => {
    const label = document.createElement("label");
    label.className = "option-card";
    label.innerHTML = `
      <input type="radio" name="${name}" value="${option.id}" ${option.id === selectedId ? "checked" : ""} />
      <span class="option-copy">
        <strong>${option.label}</strong>
        <small>${option.note}</small>
      </span>
    `;
    label.querySelector("input").addEventListener("change", () => onChange(option.id));
    target.appendChild(label);
  });
}

function createCheckboxGrid(target, options, selectedIds, onChange) {
  target.innerHTML = "";
  options.forEach((option) => {
    const label = document.createElement("label");
    label.className = "toggle-card";
    label.innerHTML = `
      <input type="checkbox" value="${option.id}" ${selectedIds.includes(option.id) ? "checked" : ""} />
      <span class="option-copy">
        <strong>${option.label}</strong>
        <small>${option.note}</small>
      </span>
    `;
    label.querySelector("input").addEventListener("change", (event) => onChange(option.id, event.target.checked));
    target.appendChild(label);
  });
}

function fillList(target, items) {
  target.innerHTML = "";
  if (!items.length) {
    const li = document.createElement("li");
    li.textContent = "暂无";
    target.appendChild(li);
    return;
  }
  items.forEach((item) => {
    const li = document.createElement("li");
    li.textContent = item;
    target.appendChild(li);
  });
}

function computeActiveSynergies(roleState) {
  const installed = new Set(roleState.installedSkills);
  const equipped = new Set(Object.values(roleState.equipped).filter(Boolean));
  return synergies.filter((entry) => {
    const skillsOk = entry.skills.every((id) => installed.has(id));
    const toolsOk = entry.tools.every((id) => equipped.has(id));
    return skillsOk && toolsOk;
  });
}

function computeLevel(roleState) {
  const synergyCount = computeActiveSynergies(roleState).length;
  const xp =
    roleState.installedSkills.length * 120 +
    roleState.hotbar.filter(Boolean).length * 90 +
    Object.values(roleState.equipped).filter(Boolean).length * 160 +
    synergyCount * 280;
  const level = Math.max(1, Math.min(30, Math.floor(xp / 320) + 1));
  const levelBase = (level - 1) * 320;
  const nextLevelBase = level * 320;
  return {
    xp,
    level,
    current: xp - levelBase,
    need: nextLevelBase - levelBase,
    ratio: Math.min(100, Math.round(((xp - levelBase) / (nextLevelBase - levelBase)) * 100)),
  };
}

function renderHero(role, roleState) {
  const profile = roleProfiles[role];
  const portrait = document.getElementById("configPortrait");
  portrait.src = profile.image;
  portrait.alt = `${profile.title}立绘`;
  portrait.style.objectPosition = profile.portraitPosition;
  document.getElementById("configClass").textContent = profile.className;
  document.getElementById("configTitle").textContent = profile.title;
  document.getElementById("configDesc").textContent = profile.desc;

  const tagBox = document.getElementById("configPersonaTags");
  tagBox.innerHTML = "";
  profile.tags.forEach((tag) => {
    const chip = document.createElement("span");
    chip.className = "persona-tag";
    chip.textContent = tag;
    tagBox.appendChild(chip);
  });

  const activeSynergies = computeActiveSynergies(roleState);
  const levelData = computeLevel(roleState);
  document.getElementById("heroSkillCount").textContent = String(roleState.installedSkills.length);
  document.getElementById("heroToolCount").textContent = String(Object.values(roleState.equipped).filter(Boolean).length);
  document.getElementById("heroSynergyCount").textContent = String(activeSynergies.length);
  document.getElementById("heroLevelText").textContent = `Lv.${levelData.level}`;
}

function renderSkillPackSwitch(role, roleState, rerender) {
  createRadioGroup(document.getElementById("skillPackSwitch"), "skillPack", packageDefs, roleState.skillPack, (value) => {
    roleState.skillPack = value;
    const defaults = roleDefaultSkills(role, value);
      roleState.installedSkills = Array.from(new Set([...roleState.installedSkills.filter((id) => skillById(id)?.pack.includes(value)), ...defaults]));
      roleState.hotbar = roleState.hotbar.map((id) => (id && roleState.installedSkills.includes(id) ? id : null));
      rerender();
  });
}

function renderSkillOverview(role, roleState) {
  const strip = document.getElementById("skillOverviewStrip");
  const roleSkills = skillCatalog.filter((skill) => skill.roles.includes(role));
  const installed = new Set(roleState.installedSkills);
  const recommended = new Set(recommendedSkillIds(role));
  const activeSynergies = computeActiveSynergies(roleState);
  const tierStats = ["low", "medium", "high"].map((tier) => {
    const total = roleSkills.filter((skill) => skill.tier === tier).length;
    const done = roleSkills.filter((skill) => skill.tier === tier && installed.has(skill.id)).length;
    return { tier, total, done };
  });
  const summaryCards = [
    {
      cls: "overview-card neutral",
      label: "构筑密度",
      value: `${roleState.installedSkills.length} / ${roleSkills.length}`,
      note: "该人格当前技能完成度",
    },
    ...tierStats.map((entry) => ({
      cls: `overview-card ${entry.tier}`,
      label: `${tierChinese(entry.tier)}天赋`,
      value: `${entry.done} / ${entry.total}`,
      note: "当前已安装",
    })),
    {
      cls: "overview-card neutral",
      label: "推荐命中",
      value: `${roleSkills.filter((skill) => recommended.has(skill.id) && installed.has(skill.id)).length} / ${recommended.size}`,
      note: activeSynergies.length ? `已成型 ${activeSynergies.length} 条联动` : "尚未形成完整联动",
    },
  ];
  strip.innerHTML = summaryCards
    .map(
      (entry) => `
        <article class="${entry.cls}">
          <span>${entry.label}</span>
          <strong>${entry.value}</strong>
          <small>${entry.note}</small>
        </article>`,
    )
    .join("");
}

function renderSkillCommandDeck(role, roleState, rerender) {
  const recommended = new Set(recommendedSkillIds(role));
  const profile = roleProfiles[role];
  const levelData = computeLevel(roleState);
  const activeSynergies = computeActiveSynergies(roleState);
  const completion = Math.round((roleState.installedSkills.length / Math.max(1, skillCatalog.filter((skill) => skill.roles.includes(role)).length)) * 100);
  const buildTier = completion >= 82 ? "宗师构筑" : completion >= 58 ? "成型构筑" : "起步构筑";
  const focus = recommendedSynergiesForRole(role).slice(0, 3);

  document.getElementById("skillBuildCard").innerHTML = `
    <div class="build-focus-top">
      <div class="build-focus-copy">
        <h4>${profile.title}</h4>
        <p>围绕 ${profile.specialty} 的技能构筑正在成型。优先补齐推荐链路，再把高频技能塞进工作栏，避免只是“装了很多”，却没有稳定打法。</p>
      </div>
      <div class="build-focus-rank">
        <span>构筑评级</span>
        <strong>${buildTier}</strong>
      </div>
    </div>
    <div class="build-focus-metrics">
      <article class="build-metric"><span>完成度</span><strong>${completion}%</strong></article>
      <article class="build-metric"><span>推荐命中</span><strong>${roleState.installedSkills.filter((id) => recommended.has(id)).length}</strong></article>
      <article class="build-metric"><span>已点主分支</span><strong>${branchOrder().filter((branch) => skillCatalog.some((skill) => skill.branch === branch && roleState.installedSkills.includes(skill.id))).length}</strong></article>
      <article class="build-metric"><span>角色等级</span><strong>Lv.${levelData.level}</strong></article>
    </div>
    <div class="build-focus-tags">
      ${profile.taskFocus.map((item) => `<span class="focus-chip">${item}</span>`).join("")}
      ${activeSynergies.map((entry) => `<span class="focus-chip">${entry.name}</span>`).join("")}
    </div>
  `;

  const branchNavigator = document.getElementById("branchNavigator");
  branchNavigator.innerHTML = [
    `<button class="branch-pill ${roleState.branchFocus === "all" ? "active" : ""}" type="button" data-branch-focus="all"><strong>全部分支</strong><small>查看完整技能版图</small></button>`,
    ...branchOrder()
      .filter((branch) => skillCatalog.some((skill) => skill.branch === branch && skill.roles.includes(role)))
      .map((branch) => {
        const total = skillCatalog.filter((skill) => skill.branch === branch && skill.roles.includes(role)).length;
        const done = skillCatalog.filter((skill) => skill.branch === branch && skill.roles.includes(role) && roleState.installedSkills.includes(skill.id)).length;
        return `<button class="branch-pill ${roleState.branchFocus === branch ? "active" : ""}" type="button" data-branch-focus="${branch}">
          <strong>${branchMeta[branch]?.short || branch}</strong>
          <small>${done}/${total} · ${branchMeta[branch]?.accent || "分支"}</small>
        </button>`;
      }),
  ].join("");
  branchNavigator.querySelectorAll("[data-branch-focus]").forEach((button) => {
    button.addEventListener("click", () => {
      roleState.branchFocus = button.dataset.branchFocus;
      rerender();
    });
  });

  const filterBar = document.getElementById("skillFilterBar");
  filterBar.innerHTML = skillFilters
    .map((filter) => `<button class="filter-pill ${roleState.skillFilter === filter.id ? "active" : ""}" type="button" data-skill-filter="${filter.id}">${filter.label}</button>`)
    .join("");
  filterBar.querySelectorAll("[data-skill-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      roleState.skillFilter = button.dataset.skillFilter;
      rerender();
    });
  });

  const skillSynergyStrip = document.getElementById("skillSynergyStrip");
  skillSynergyStrip.innerHTML = (focus.length ? focus : recommendedSynergiesForRole(role).slice(0, 1))
    .map((entry) => {
      const missingSkills = entry.skills.filter((id) => !roleState.installedSkills.includes(id)).map((id) => skillById(id)?.name || id);
      const equippedTools = new Set(Object.values(roleState.equipped).filter(Boolean));
      const missingTools = entry.tools.filter((id) => !equippedTools.has(id)).map((id) => toolById(id)?.name || id);
      const ready = !missingSkills.length && !missingTools.length;
      return `
        <article class="forge-card">
          <span>${ready ? "已点亮联动" : "建议补齐联动"}</span>
          <h4>${entry.name}</h4>
          <p>${entry.note}</p>
          <ul>
            <li>缺失技能: ${missingSkills.length ? missingSkills.join("、") : "无"}</li>
            <li>缺失装备: ${missingTools.length ? missingTools.join("、") : "无"}</li>
          </ul>
        </article>
      `;
    })
    .join("");
}

function renderSkillWorkbench(role, roleState, rerender) {
  const dock = document.getElementById("skillNodeDock");
  dock.innerHTML = "";
  roleState.pinnedSkills.forEach((skillId, index) => {
    const card = document.createElement("button");
    card.type = "button";
    card.className = "skill-dock-slot";
    card.dataset.index = String(index);
    const skill = skillId ? skillById(skillId) : null;
    card.innerHTML = skill
      ? `<span class="dock-index">祭坛 ${index + 1}</span><strong>${skill.name}</strong><small>${skill.desc}</small>`
      : `<span class="dock-index">祭坛 ${index + 1}</span><strong>拖入节点</strong><small>锁定你的核心打法</small>`;
    card.addEventListener("dragover", (event) => event.preventDefault());
    card.addEventListener("drop", (event) => {
      event.preventDefault();
      const raw = event.dataTransfer.getData("text/plain");
      if (!raw) return;
      const payload = JSON.parse(raw);
      if (payload.type !== "skill" || !roleState.installedSkills.includes(payload.id)) return;
      roleState.pinnedSkills[index] = payload.id;
      roleState.selectedSkillId = payload.id;
      rerender();
    });
    card.addEventListener("click", () => {
      if (skillId) {
        roleState.selectedSkillId = skillId;
        rerender();
      }
    });
    dock.appendChild(card);
  });

  const inspector = document.getElementById("skillNodeInspector");
  const selected = skillById(roleState.selectedSkillId);
  if (!selected) {
    inspector.innerHTML = `<p class="panel-tip">点击任意节点后，这里会显示它的依赖、状态、联动和快捷动作。</p>`;
    return;
  }
  const recommended = recommendedSkillIds(role);
  const inHotbar = roleState.hotbar.includes(selected.id);
  const inDock = roleState.pinnedSkills.includes(selected.id);
  const linkedSynergies = synergies.filter((entry) => entry.skills.includes(selected.id)).map((entry) => entry.name);
  inspector.innerHTML = `
    <article class="node-inspector-card">
      <span class="skill-badge ${selected.tier}">${tierChinese(selected.tier)}</span>
      <h4>${selected.name}</h4>
      <p>${selected.desc}</p>
      <div class="dep-chip-row">
        ${selected.deps.length ? selected.deps.map((dep) => `<span class="dep-chip">${skillById(dep)?.name || dep}</span>`).join("") : `<span class="dep-chip empty">无依赖</span>`}
      </div>
      <div class="dep-chip-row">
        ${linkedSynergies.length ? linkedSynergies.map((name) => `<span class="dep-chip">${name}</span>`).join("") : `<span class="dep-chip empty">暂无联动</span>`}
      </div>
      <div class="node-inspector-stats">
        <article class="item-stat"><span>分支</span><strong>${selected.branch}</strong></article>
        <article class="item-stat"><span>工作栏</span><strong>${inHotbar ? "已放入" : "未放入"}</strong></article>
        <article class="item-stat"><span>祭坛</span><strong>${inDock ? "已锁定" : "未锁定"}</strong></article>
      </div>
      <div class="skill-actions">
        <button type="button" data-node-action="${roleState.installedSkills.includes(selected.id) ? "remove" : "install"}">${roleState.installedSkills.includes(selected.id) ? "删除技能" : "安装技能"}</button>
        <button type="button" data-node-action="hotbar">${inHotbar ? "撤下工作栏" : "加入工作栏"}</button>
        <button type="button" data-node-action="dock">${inDock ? "移出祭坛" : "锁定祭坛"}</button>
      </div>
      <p class="panel-tip">推荐状态：${recommended.includes(selected.id) ? "该技能属于当前人格推荐构筑。" : "该技能是补充选项。"} 拖动标题左侧握把可调整节点位置。</p>
    </article>
  `;
  inspector.querySelectorAll("[data-node-action]").forEach((button) => {
    button.addEventListener("click", () => {
      const action = button.dataset.nodeAction;
      if (action === "install") {
        const missingDeps = selected.deps.filter((dep) => !roleState.installedSkills.includes(dep));
        roleState.installedSkills = Array.from(new Set([...roleState.installedSkills, ...missingDeps, selected.id]));
      } else if (action === "remove") {
        roleState.installedSkills = roleState.installedSkills.filter((id) => id !== selected.id);
        roleState.hotbar = roleState.hotbar.map((id) => (id === selected.id ? null : id));
        roleState.pinnedSkills = roleState.pinnedSkills.map((id) => (id === selected.id ? null : id));
      } else if (action === "hotbar") {
        if (inHotbar) {
          roleState.hotbar = roleState.hotbar.map((id) => (id === selected.id ? null : id));
        } else {
          const emptyIndex = roleState.hotbar.findIndex((value) => !value);
          roleState.hotbar[emptyIndex >= 0 ? emptyIndex : 0] = selected.id;
        }
      } else if (action === "dock") {
        if (inDock) {
          roleState.pinnedSkills = roleState.pinnedSkills.map((id) => (id === selected.id ? null : id));
        } else {
          const emptyIndex = roleState.pinnedSkills.findIndex((value) => !value);
          roleState.pinnedSkills[emptyIndex >= 0 ? emptyIndex : 0] = selected.id;
        }
      }
      rerender();
    });
  });
}

function renderHotbar(roleState, rerender) {
  const hotbar = document.getElementById("skillHotbar");
  hotbar.innerHTML = "";
  roleState.hotbar.forEach((skillId, index) => {
    const slot = document.createElement("button");
    slot.type = "button";
    slot.className = "hotbar-slot";
    slot.dataset.index = String(index);
    slot.innerHTML = skillId
      ? `<span class="hotbar-index">${index + 1}</span><strong>${skillById(skillId)?.name || skillId}</strong>`
      : `<span class="hotbar-index">${index + 1}</span><em>拖入技能</em>`;
    slot.addEventListener("dragover", (event) => event.preventDefault());
    slot.addEventListener("drop", (event) => {
      event.preventDefault();
      const payload = JSON.parse(event.dataTransfer.getData("text/plain"));
      if (payload.type !== "skill" || !roleState.installedSkills.includes(payload.id)) {
        return;
      }
      roleState.hotbar[index] = payload.id;
      rerender();
    });
    slot.addEventListener("click", () => {
      roleState.hotbar[index] = null;
      rerender();
    });
    hotbar.appendChild(slot);
  });
}

function branchOrder() {
  return ["控制中枢", "执行系统", "情报网络", "知识文档", "金融引擎", "增长工坊", "创意工坊", "视觉理解"];
}

function drawBranchLinks(section) {
  const board = section.querySelector(".talent-board");
  const svg = section.querySelector(".skill-link-layer");
  if (!board || !svg) return;
  svg.innerHTML = "";
  const boardRect = board.getBoundingClientRect();
  const nodeMap = new Map();
  section.querySelectorAll("[data-skill-id]").forEach((node) => {
    nodeMap.set(node.dataset.skillId, node);
  });
  nodeMap.forEach((node, skillId) => {
    const skill = skillById(skillId);
    if (!skill) return;
    const toRect = node.getBoundingClientRect();
    const x2 = toRect.left - boardRect.left + 14;
    const y2 = toRect.top - boardRect.top + toRect.height / 2;
    skill.deps.forEach((depId) => {
      const depNode = nodeMap.get(depId);
      if (!depNode) return;
      const depRect = depNode.getBoundingClientRect();
      const x1 = depRect.right - boardRect.left - 14;
      const y1 = depRect.top - boardRect.top + depRect.height / 2;
      const installed = node.classList.contains("installed") && depNode.classList.contains("installed");
      svg.insertAdjacentHTML(
        "beforeend",
        `<line class="${installed ? "installed" : ""}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"></line><circle cx="${x2}" cy="${y2}" r="2.4"></circle>`,
      );
    });
  });
}

function enableNodeDragging(section, roleState) {
  const board = section.querySelector(".talent-board");
  if (!board) return;
  const boardRect = () => board.getBoundingClientRect();
  section.querySelectorAll(".talent-node").forEach((node) => {
    const grip = node.querySelector(".talent-node-grip");
    if (!grip) return;
    grip.addEventListener("pointerdown", (event) => {
      event.preventDefault();
      event.stopPropagation();
      const skillId = node.dataset.skillId;
      const startRect = node.getBoundingClientRect();
      const boardBox = boardRect();
      const startX = startRect.left - boardBox.left;
      const startY = startRect.top - boardBox.top;
      const pointerStartX = event.clientX;
      const pointerStartY = event.clientY;
      const move = (moveEvent) => {
        const dx = moveEvent.clientX - pointerStartX;
        const dy = moveEvent.clientY - pointerStartY;
        const nextX = Math.max(10, Math.min(board.clientWidth - node.offsetWidth - 10, startX + dx));
        const nextY = Math.max(12, Math.min(board.clientHeight - node.offsetHeight - 10, startY + dy));
        node.style.left = `${nextX}px`;
        node.style.top = `${nextY}px`;
        drawBranchLinks(section);
      };
      const up = (upEvent) => {
        const dx = upEvent.clientX - pointerStartX;
        const dy = upEvent.clientY - pointerStartY;
        const skill = skillById(skillId);
        const branchSkills = skillCatalog.filter((item) => item.branch === skill.branch && item.roles.includes(section.dataset.role));
        const tierSkills = branchSkills.filter((item) => item.tier === skill.tier);
        const index = tierSkills.findIndex((item) => item.id === skillId);
        const base = nodeBasePosition(skill.tier, Math.max(index, 0), Math.max(tierSkills.length, 1));
        roleState.skillNodeOffsets[skillId] = {
          x: Math.round((parseFloat(node.style.left) || startX + dx) - base.x),
          y: Math.round((parseFloat(node.style.top) || startY + dy) - base.y),
        };
        persistRoleState(readRole(), roleState);
        window.removeEventListener("pointermove", move);
        window.removeEventListener("pointerup", up);
        drawBranchLinks(section);
      };
      window.addEventListener("pointermove", move);
      window.addEventListener("pointerup", up, { once: true });
    });
  });
}

function renderSkillForest(role, roleState, rerender) {
  const skillForest = document.getElementById("skillForest");
  skillForest.innerHTML = "";
  const currentPackIndex = packageIndex(roleState.skillPack);
  const recommended = new Set(recommendedSkillIds(role));

  branchOrder().forEach((branch) => {
    const skills = skillCatalog.filter((skill) => skill.branch === branch && skill.roles.includes(role));
    if (!skills.length) return;
    if (roleState.branchFocus !== "all" && roleState.branchFocus !== branch) return;
    const filteredSkills = skills.filter((skill) => skillMatchesFilter(skill, roleState, currentPackIndex, recommended));
    if (!filteredSkills.length) return;

    const section = document.createElement("article");
    section.className = "config-panel skill-branch";
    section.dataset.role = role;
    const tierColumns = ["low", "medium", "high"].map((tier) => {
      const filteredTierSkills = filteredSkills.filter((skill) => skill.tier === tier);
      return `
        <article class="talent-lane talent-lane-${tier}">
          <header class="talent-lane-head">
            <span class="legend-chip ${tier}">${tierChinese(tier)}</span>
            <strong>${filteredTierSkills.length}</strong>
          </header>
          <p>${branchMeta[branch]?.accent || "专精"} ${tierChinese(tier)} 段</p>
        </article>
      `;
    }).join("");
    const nodeMarkup = ["low", "medium", "high"].flatMap((tier) => {
      const tierSkills = filteredSkills.filter((skill) => skill.tier === tier);
      return tierSkills
        .map((skill) => {
          const unlocked = packageIndex(skill.tier) <= currentPackIndex;
          const installed = roleState.installedSkills.includes(skill.id);
          const hotbar = roleState.hotbar.includes(skill.id);
          const depsReady = skill.deps.every((dep) => roleState.installedSkills.includes(dep));
          const recommendedFlag = recommended.has(skill.id);
          const index = tierSkills.findIndex((entry) => entry.id === skill.id);
          const base = nodeBasePosition(tier, index, Math.max(tierSkills.length, 1));
          const offset = nodeStoredOffset(roleState, skill.id);
          const left = base.x + offset.x;
          const top = base.y + offset.y;
          return `
            <article class="talent-node ${roleState.selectedSkillId === skill.id ? "selected" : ""} ${installed ? "installed" : ""} ${recommendedFlag ? "recommended" : ""} ${unlocked ? "" : "locked"}" draggable="${installed}" data-skill-id="${skill.id}" style="left:${left}px; top:${top}px;">
              <button class="talent-node-grip" type="button" aria-label="拖动节点">✥</button>
              <div class="skill-card-head">
                <div class="skill-card-topline">
                  <span class="skill-badge ${skill.tier}">${tierChinese(skill.tier)}</span>
                  <span class="skill-role-mark">${branchMeta[branch]?.accent || "专精"}</span>
                </div>
                <strong>${skill.name}</strong>
              </div>
              <div class="skill-state-row">
                ${recommendedFlag ? `<span class="state-chip gold">推荐</span>` : ""}
                ${hotbar ? `<span class="state-chip gold">工作栏</span>` : ""}
                ${depsReady ? `<span class="state-chip">依赖已就绪</span>` : `<span class="state-chip red">依赖未齐</span>`}
              </div>
              <div class="skill-meta"><span>${installed ? "已装配" : unlocked ? "可安装" : "需更高档位"}</span></div>
              <div class="skill-actions">
                <button type="button" data-action="${installed ? "remove" : "install"}" data-skill="${skill.id}" ${unlocked ? "" : "disabled"}>
                  ${installed ? "删除" : "安装"}
                </button>
                <button type="button" data-action="slot" data-skill="${skill.id}" ${installed ? "" : "disabled"}>${hotbar ? "撤下" : "热栏"}</button>
              </div>
            </article>
          `;
        });
    }).join("");

    const mastery = skills.filter((skill) => roleState.installedSkills.includes(skill.id)).length;
    const ratio = Math.round((mastery / Math.max(1, skills.length)) * 100);
    const branchRecHits = skills.filter((skill) => recommended.has(skill.id) && roleState.installedSkills.includes(skill.id)).length;
    const boardHeight = Math.max(
      360,
      ...["low", "medium", "high"].map((tier) => {
        const count = filteredSkills.filter((skill) => skill.tier === tier).length;
        return 160 + Math.max(0, count - 1) * 120;
      }),
    );

    section.innerHTML = `
      <div class="panel-head">
        <p class="panel-index">${branch}</p>
        <h3>${branch}</h3>
      </div>
      <div class="branch-mastery">
        <div>
          <span>掌握进度</span>
          <strong>${mastery} / ${skills.length}</strong>
        </div>
        <div class="branch-meter">
          <div class="branch-meter-track"><div class="branch-meter-fill" style="width:${ratio}%"></div></div>
        </div>
      </div>
      <div class="branch-mastery-meta">
        <p>${branchMeta[branch]?.note || "角色专精分支"}</p>
        <p>推荐命中 ${branchRecHits} · 筛选命中 ${filteredSkills.length}/${skills.length}</p>
      </div>
      <div class="talent-board" style="height:${boardHeight}px;">
        <div class="talent-board-grid">${tierColumns}</div>
        <svg class="skill-link-layer" aria-hidden="true"></svg>
        <div class="talent-node-layer">${nodeMarkup}</div>
      </div>
    `;
    skillForest.appendChild(section);
  });

  skillForest.querySelectorAll(".talent-node").forEach((card) => {
    card.addEventListener("dragstart", (event) => {
      const skillId = card.querySelector("[data-skill]")?.dataset.skill;
      if (!skillId || !roleState.installedSkills.includes(skillId)) return;
      event.dataTransfer.setData("text/plain", JSON.stringify({ type: "skill", id: skillId }));
    });
    card.addEventListener("click", (event) => {
      if (event.target.closest("button")) return;
      roleState.selectedSkillId = card.dataset.skillId;
      rerender();
    });
  });

  skillForest.querySelectorAll("[data-action='install']").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.skill;
      const skill = skillById(id);
      const missingDeps = skill.deps.filter((dep) => !roleState.installedSkills.includes(dep));
      roleState.installedSkills = Array.from(new Set([...roleState.installedSkills, ...missingDeps, id]));
      rerender();
    });
  });

  skillForest.querySelectorAll("[data-action='remove']").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.skill;
      roleState.installedSkills = roleState.installedSkills.filter((skillId) => skillId !== id);
      roleState.hotbar = roleState.hotbar.map((skillId) => (skillId === id ? null : skillId));
      rerender();
    });
  });

  skillForest.querySelectorAll("[data-action='slot']").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.skill;
      if (roleState.hotbar.includes(id)) {
        roleState.hotbar = roleState.hotbar.map((value) => (value === id ? null : value));
      } else {
        const emptyIndex = roleState.hotbar.findIndex((value) => !value);
        roleState.hotbar[emptyIndex >= 0 ? emptyIndex : 0] = id;
      }
      roleState.selectedSkillId = id;
      rerender();
    });
  });

  skillForest.querySelectorAll(".skill-branch").forEach((section) => {
    drawBranchLinks(section);
    enableNodeDragging(section, roleState);
  });
}

function renderEquipment(role, roleState, rerender) {
  const equippedIds = Object.values(roleState.equipped).filter(Boolean);
  const activeSynergies = computeActiveSynergies(roleState);
  const relevantToolSynergies = synergies.filter((entry) => entry.tools.some((id) => recommendedToolIds(role).includes(id)));
  const totalPower = equippedIds.reduce((sum, id) => sum + rarityScore(toolById(id)?.rarity), 0);

  document.getElementById("armoryStatusStrip").innerHTML = `
    <article class="armory-stat"><span>已穿戴</span><strong>${equippedIds.length}/${SLOT_ORDER.length}</strong></article>
    <article class="armory-stat"><span>军械强度</span><strong>${totalPower}</strong></article>
    <article class="armory-stat"><span>激活套装</span><strong>${activeSynergies.length}</strong></article>
    <article class="armory-stat"><span>背包容量</span><strong>${roleState.inventory.length}</strong></article>
  `;
  const mainhand = toolById(roleState.equipped.mainhand);
  const offhand = toolById(roleState.equipped.offhand);
  document.getElementById("armoryWeaponRack").innerHTML = `
    <article class="weapon-hanger ${offhand ? offhand.rarity : "empty"}">
      <span>副手悬挂</span>
      <strong>${offhand ? offhand.name : "空置"}</strong>
      <small>${offhand ? `${offhand.type} · ${slotLabel(offhand.slot)}` : "拖拽 Tool / MCP 到副手槽位"}</small>
    </article>
    <article class="weapon-hanger ${mainhand ? mainhand.rarity : "empty"}">
      <span>主手悬挂</span>
      <strong>${mainhand ? mainhand.name : "空置"}</strong>
      <small>${mainhand ? `${mainhand.type} · ${slotLabel(mainhand.slot)}` : "拖拽 Tool / MCP 到主手槽位"}</small>
    </article>
  `;

  document.querySelectorAll(".equipment-slot").forEach((slotEl) => {
    const slot = slotEl.dataset.slot;
    const itemId = roleState.equipped[slot];
    const item = itemId ? toolById(itemId) : null;
    const button = slotEl.querySelector("button");
    slotEl.className = `equipment-slot slot-${slot} ${item ? `${item.rarity} active` : ""}`;
    button.innerHTML = item
      ? `<span class="slot-item-type">${item.type}</span>${item.name}`
      : `<span class="slot-item-type">${slotLabel(slot)}</span>空槽`;
    button.dataset.slot = slot;
    button.onclick = () => {
      roleState.equipped[slot] = null;
      rerender();
    };
    slotEl.onclick = () => {
      if (item) {
        roleState.selectedToolId = item.id;
        rerender();
      }
    };
    slotEl.ondragover = (event) => event.preventDefault();
    slotEl.ondrop = (event) => {
      event.preventDefault();
      const payload = JSON.parse(event.dataTransfer.getData("text/plain"));
      if (payload.type !== "tool") return;
      const tool = toolById(payload.id);
      if (!tool || tool.slot !== slot) return;
      roleState.equipped[slot] = tool.id;
      if (!roleState.inventory.includes(tool.id)) {
        roleState.inventory.push(tool.id);
      }
      roleState.selectedToolId = tool.id;
      rerender();
    };
  });

  const inventoryGrid = document.getElementById("inventoryGrid");
  inventoryGrid.innerHTML = "";
  const inventoryFilterBar = document.getElementById("inventoryFilterBar");
  inventoryFilterBar.innerHTML = inventoryFilters
    .map((filter) => `<button class="inventory-pill ${roleState.inventoryFilter === filter.id ? "active" : ""}" type="button" data-tool-filter="${filter.id}">${filter.label}</button>`)
    .join("");
  inventoryFilterBar.querySelectorAll("[data-tool-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      roleState.inventoryFilter = button.dataset.toolFilter;
      rerender();
    });
  });

  toolCatalog
    .filter((tool) => tool.roles.includes(role) && toolMatchesFilter(tool, roleState))
    .forEach((tool) => {
      const installed = roleState.inventory.includes(tool.id);
      const equipped = equippedIds.includes(tool.id);
      const card = document.createElement("article");
      card.className = `inventory-card ${installed ? "owned" : ""} ${equipped ? "equipped-card" : ""} ${tool.rarity}`;
      card.draggable = installed;
      card.innerHTML = `
        <div class="inventory-icon">${tool.type.slice(0, 2)}</div>
        <p class="inventory-type">${tool.type}</p>
        <h4>${tool.name}</h4>
        <p>${tool.desc}</p>
        <div class="inventory-meta">
          <span>${slotLabel(tool.slot)} · ${tool.rarity}</span>
          <button type="button" data-tool="${tool.id}">${installed ? (equipped ? "已装备" : "装备") : "安装"}</button>
        </div>
      `;
      card.addEventListener("click", () => {
        roleState.selectedToolId = tool.id;
        rerender();
      });
      card.addEventListener("dragstart", (event) => {
        if (!installed) return;
        event.dataTransfer.setData("text/plain", JSON.stringify({ type: "tool", id: tool.id }));
      });
      card.querySelector("button").addEventListener("click", () => {
        if (!installed) {
          roleState.inventory.push(tool.id);
        } else if (!equipped) {
          roleState.equipped[tool.slot] = tool.id;
        }
        roleState.selectedToolId = tool.id;
        rerender();
      });
      inventoryGrid.appendChild(card);
    });

  const stashGrid = document.getElementById("stashGrid");
  stashGrid.innerHTML = "";
  const stashItems = toolCatalog.filter((tool) => tool.roles.includes(role) && !roleState.inventory.includes(tool.id) && toolMatchesFilter(tool, roleState));
  stashItems.forEach((tool) => {
    const card = document.createElement("article");
    card.className = `stash-card ${tool.rarity}`;
    card.innerHTML = `
      <div class="inventory-icon">${tool.type.slice(0, 2)}</div>
      <p class="inventory-type">${tool.type}</p>
      <h4>${tool.name}</h4>
      <p>${tool.desc}</p>
      <button type="button" data-stash-tool="${tool.id}">加入背包</button>
    `;
    card.addEventListener("click", () => {
      roleState.selectedToolId = tool.id;
      rerender();
    });
    card.querySelector("button").addEventListener("click", () => {
      roleState.inventory.push(tool.id);
      roleState.selectedToolId = tool.id;
      rerender();
    });
    stashGrid.appendChild(card);
  });

  document.getElementById("armoryBonusPanel").innerHTML = (relevantToolSynergies.length ? relevantToolSynergies.slice(0, 3) : synergies.slice(0, 2))
    .map((entry) => {
      const missingTools = entry.tools.filter((id) => !equippedIds.includes(id)).map((id) => toolById(id)?.name || id);
      const missingSkills = entry.skills.filter((id) => !roleState.installedSkills.includes(id)).map((id) => skillById(id)?.name || id);
      return `
        <article class="armory-bonus-card">
          <span>${missingTools.length || missingSkills.length ? "未完成套装" : "已激活套装"}</span>
          <h4>${entry.name}</h4>
          <p>${entry.note}</p>
          <ul>
            <li>缺失技能: ${missingSkills.length ? missingSkills.join("、") : "无"}</li>
            <li>缺失装备: ${missingTools.length ? missingTools.join("、") : "无"}</li>
          </ul>
        </article>
      `;
    })
    .join("");

  renderItemDetail(roleState);
}

function renderItemDetail(roleState) {
  const panel = document.getElementById("itemDetailPanel");
  const tool = toolById(roleState.selectedToolId);
  if (!tool) {
    panel.innerHTML = `
      <p class="inventory-type">选中物品</p>
      <h4>尚未查看</h4>
      <p>点击或拖拽物品后，这里会显示详细说明、槽位、稀有度与联动效果。</p>
    `;
    return;
  }
  const linked = synergies.filter((entry) => entry.tools.includes(tool.id)).map((entry) => entry.name);
  const equipped = Object.values(roleState.equipped).includes(tool.id);
  const owned = roleState.inventory.includes(tool.id);
  const relatedSkills = skillCatalog
    .filter((skill) => synergies.some((entry) => entry.tools.includes(tool.id) && entry.skills.includes(skill.id)))
    .map((skill) => skill.name);
  panel.innerHTML = `
    <p class="inventory-type">${tool.type} · ${tool.rarity}</p>
    <h4>${tool.name}</h4>
    <p>${tool.desc}</p>
    <div class="item-detail-stats">
      <article class="item-stat"><span>槽位</span><strong>${slotLabel(tool.slot)}</strong></article>
      <article class="item-stat"><span>状态</span><strong>${equipped ? "已装备" : owned ? "已安装" : "仓库中"}</strong></article>
      <article class="item-stat"><span>品质</span><strong>${tool.rarity}</strong></article>
    </div>
    <div class="item-detail-meta">
      <span>槽位: ${slotLabel(tool.slot)}</span>
      <span>角色: ${tool.roles.map((role) => roleProfiles[role]?.title || role).join(" / ")}</span>
    </div>
    <div class="dep-chip-row">${linked.length ? linked.map((name) => `<span class="dep-chip">${name}</span>`).join("") : `<span class="dep-chip empty">暂无联动</span>`}</div>
    <div class="dep-chip-row">${relatedSkills.length ? relatedSkills.map((name) => `<span class="dep-chip">${name}</span>`).join("") : `<span class="dep-chip empty">暂无关联技能</span>`}</div>
  `;
}

function renderStatus(role, roleState, rerender) {
  const bars = [
    { label: "执行力", value: Math.min(100, roleState.installedSkills.length * 3 + roleState.hotbar.filter(Boolean).length * 8) },
    { label: "情报力", value: Math.min(100, roleState.installedSkills.filter((id) => ["web-search", "tavily-search", "news-radar", "multi-search-engine"].includes(id)).length * 22) },
    { label: "创作力", value: Math.min(100, roleState.installedSkills.filter((id) => ["frontend-design", "gemini-image-service", "nano-banana-service", "grok-imagine-1.0-video"].includes(id)).length * 25) },
    { label: "自动化", value: Math.min(100, roleState.installedSkills.filter((id) => ["openclaw-cron-setup", "proactive-agent", "capability-evolver"].includes(id)).length * 28) },
    { label: "文档力", value: Math.min(100, roleState.installedSkills.filter((id) => ["pdf", "docx", "pptx", "xlsx", "summarize"].includes(id)).length * 18) },
  ];
  const statusBars = document.getElementById("statusBars");
  statusBars.innerHTML = bars
    .map(
      (bar) => `
        <div class="status-row">
          <div class="status-row-head"><strong>${bar.label}</strong><span>${bar.value}</span></div>
          <div class="status-track"><div class="status-fill" style="width:${bar.value}%"></div></div>
        </div>`,
    )
    .join("");

  createRadioGroup(document.getElementById("modelRouteOptions"), "modelRoute", modelRoutes, roleState.modelRoute, (value) => {
    roleState.modelRoute = value;
    rerender();
  });
  createRadioGroup(document.getElementById("tokenRuleOptions"), "tokenRule", tokenRules, roleState.tokenRule, (value) => {
    roleState.tokenRule = value;
    rerender();
  });
  createCheckboxGrid(document.getElementById("securityOptions"), securityOptions, roleState.security, (id, checked) => {
    roleState.security = checked ? [...roleState.security, id] : roleState.security.filter((item) => item !== id);
    rerender();
  });
}

function renderTasks(role, roleState) {
  const questBoard = document.getElementById("questBoard");
  const activeSynergies = computeActiveSynergies(roleState);
  const profile = roleProfiles[role];
  const quests = [
    { title: "主线任务", body: `围绕 ${profile.specialty} 构建角色默认工作流。`, reward: "经验 +150" },
    { title: "技能任务", body: `当前已安装 ${roleState.installedSkills.length} 个技能，继续补齐关键依赖。`, reward: "技能位 +1" },
    { title: "装备任务", body: `完成 ${Object.values(roleState.equipped).filter(Boolean).length} / ${SLOT_ORDER.length} 个槽位装备。`, reward: "工具槽强度 +1" },
    { title: "联动任务", body: activeSynergies.length ? `已触发 ${activeSynergies.length} 个联动效果，继续叠加复合流派。` : "当前尚未形成联动，优先补齐一条完整组合。", reward: "联动经验 +200" },
  ];
  questBoard.innerHTML = quests
    .map(
      (quest) => `
        <article class="quest-card">
          <h4>${quest.title}</h4>
          <p>${quest.body}</p>
          <span>${quest.reward}</span>
        </article>`,
    )
    .join("");

  const defaultWorkflow = [
    `读取 ${profile.title} 的当前构筑与约束`,
    "优先调用工作栏技能完成高频任务",
    "缺少能力时从技能树安装并补入工作栏",
    "如需跨工具联动，优先补齐装备槽位",
    "执行后写入复盘与升级计划",
  ];
  fillList(document.getElementById("workflowList"), defaultWorkflow);
  fillList(document.getElementById("toggleList"), ["主动汇报", "结果复盘", "命令行执行", "条件分派"]);
}

function renderLevels(roleState) {
  const levelData = computeLevel(roleState);
  document.getElementById("levelCaption").textContent = `Lv.${levelData.level} ${levelData.level >= 20 ? "宗师" : levelData.level >= 10 ? "老兵" : "新兵"}`;
  document.getElementById("xpFill").style.width = `${levelData.ratio}%`;
  document.getElementById("xpCopy").textContent = `当前经验 ${levelData.current} / ${levelData.need} · 总经验 ${levelData.xp}`;

  const perkList = document.getElementById("perkList");
  const perks = [
    `工作栏容量 ${Math.min(HOTBAR_SIZE, 3 + Math.floor(levelData.level / 5))} / ${HOTBAR_SIZE}`,
    `已装技能 ${roleState.installedSkills.length}`,
    `已装工具 ${Object.values(roleState.equipped).filter(Boolean).length}`,
    `激活联动 ${computeActiveSynergies(roleState).length}`,
  ];
  perkList.innerHTML = perks.map((perk) => `<article class="perk-card">${perk}</article>`).join("");

  const synergyGrid = document.getElementById("synergyGrid");
  const active = computeActiveSynergies(roleState);
  synergyGrid.innerHTML = (active.length ? active : [{ name: "未激活", note: "补齐技能依赖与工具装备后会在这里出现联动效果。" }])
    .map((entry) => `<article class="synergy-card"><h4>${entry.name}</h4><p>${entry.note}</p></article>`)
    .join("");
}

function renderSummary(role, roleState) {
  const activeSynergies = computeActiveSynergies(roleState);
  document.getElementById("summaryRole").textContent = roleProfiles[role].title;
  document.getElementById("summaryModel").textContent = optionLabel(modelRoutes, roleState.modelRoute);
  document.getElementById("summarySkillPack").textContent = optionLabel(packageDefs, roleState.skillPack);
  document.getElementById("summaryTokenRule").textContent = optionLabel(tokenRules, roleState.tokenRule);
  fillList(
    document.getElementById("summaryHotbar"),
    roleState.hotbar.filter(Boolean).map((id) => skillById(id)?.name || id),
  );
  fillList(
    document.getElementById("summaryTools"),
    Object.values(roleState.equipped)
      .filter(Boolean)
      .map((id) => toolById(id)?.name || id),
  );
  fillList(document.getElementById("summarySecurity"), roleState.security.map((id) => optionLabel(securityOptions, id)));
  fillList(document.getElementById("summarySynergies"), activeSynergies.map((item) => item.name));
  document.getElementById("summaryCommand").textContent = buildCommand(role, roleState);
}

function rerender(role, roleState) {
  Object.assign(roleState, normalizeRoleState(role, roleState));
  persistRoleState(role, roleState);
  renderHero(role, roleState);
  renderSkillPackSwitch(role, roleState, () => rerender(role, roleState));
  renderSkillOverview(role, roleState);
  renderSkillCommandDeck(role, roleState, () => rerender(role, roleState));
  renderSkillWorkbench(role, roleState, () => rerender(role, roleState));
  renderHotbar(roleState, () => rerender(role, roleState));
  renderSkillForest(role, roleState, () => rerender(role, roleState));
  renderEquipment(role, roleState, () => rerender(role, roleState));
  renderStatus(role, roleState, () => rerender(role, roleState));
  renderTasks(role, roleState);
  renderLevels(roleState);
  renderSummary(role, roleState);
  setActiveTab(roleState, roleState.activeTab);
}

function bindTabs(role, roleState) {
  document.querySelectorAll(".tab-button").forEach((button) => {
    button.addEventListener("click", () => {
      roleState.activeTab = button.dataset.tab;
      rerender(role, roleState);
    });
  });
}

function bootstrap() {
  const role = readRole();
  window.localStorage.setItem("openclaw.persona.role", role);
  const roleState = loadRoleState(role);
  const requestedTab = readRequestedTab();
  if (requestedTab) {
    roleState.activeTab = requestedTab;
  }
  const backLink = document.getElementById("backToLoadout");
  backLink.href = `./loadout.html?role=${encodeURIComponent(role)}`;
  bindTabs(role, roleState);
  rerender(role, roleState);

  document.getElementById("copySummaryBtn").addEventListener("click", async () => {
    const text = document.getElementById("summaryCommand").textContent;
    await navigator.clipboard.writeText(text);
    const button = document.getElementById("copySummaryBtn");
    button.textContent = "已复制摘要";
    window.setTimeout(() => {
      button.textContent = "复制方案摘要";
    }, 1200);
  });

  document.getElementById("copyEnvBtn").addEventListener("click", async () => {
    await navigator.clipboard.writeText(buildEnvBlock(role, loadRoleState(role)));
    const button = document.getElementById("copyEnvBtn");
    button.textContent = "已复制环境块";
    window.setTimeout(() => {
      button.textContent = "复制环境块";
    }, 1200);
  });

  document.getElementById("downloadPresetBtn").addEventListener("click", () => {
    const fresh = loadRoleState(role);
    const blob = new Blob([JSON.stringify(computePresetPayload(role, fresh), null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `openclaw-${role}-profile.json`;
    anchor.click();
    URL.revokeObjectURL(url);
    const button = document.getElementById("downloadPresetBtn");
    button.textContent = "已下载配置";
    window.setTimeout(() => {
      button.textContent = "下载配置档案";
    }, 1200);
  });
}

bootstrap();
