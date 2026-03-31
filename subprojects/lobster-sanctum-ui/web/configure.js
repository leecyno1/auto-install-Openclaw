const defaultRole = "druid";
const stateKey = "openclaw.command.center";
const runtimeProjectionKey = "openclaw.runtime.world";
const identityKey = "openclaw.identity.profile";
let serverCatalogRole = null;
const runtimeWorldPort = 19000;
const HOTBAR_SIZE = 6;
const BAG_PAGE_SIZE = 20;
const STASH_PAGE_SIZE = 12;
const identityDefaults = {
  assistantName: "Clawd",
  userName: "主人",
  region: "中国大陆",
  timezone: "Asia/Shanghai",
  goal: "综合任务协作",
  personality: "严谨、务实、可协作",
  workStyle: "先分析后执行，阶段性汇报",
};
const SLOT_ORDER = ["head", "shoulders", "core", "mainhand", "offhand", "belt", "legs", "boots", "ring", "chest"];
const SLOT_POSITION_CLASS = {
  head: "slot-head",
  shoulders: "slot-shoulders",
  core: "slot-core",
  mainhand: "slot-mainhand",
  offhand: "slot-offhand",
  belt: "slot-belt",
  legs: "slot-legs",
  boots: "slot-boots",
  ring: "slot-ring",
  chest: "slot-chest",
};

const pixelRoleImage = (role) => `./assets/pixel-roles/${role}.png`;

const roleProfiles = {
  druid: {
    className: "通用总管",
    title: "万金油 · 德鲁伊",
    desc: "适合绝大多数日常工作，能帮你排任务、查资料、写邮件、盯进度。",
    image: pixelRoleImage("druid"),
    portraitPosition: "center center",
    tags: ["综合协同", "主动巡航", "长期陪跑"],
    specialty: "综合协同",
    taskFocus: ["日程管理", "邮件草拟", "综合搜索", "资料整理"],
  },
  assassin: {
    className: "投资分析",
    title: "分析员 · 刺客",
    desc: "适合做投资分析、公司调研、行业比较、寻找机会和风险。",
    image: pixelRoleImage("assassin"),
    portraitPosition: "center center",
    tags: ["机会扫描", "估值解剖", "风险捕捉"],
    specialty: "情报分析",
    taskFocus: ["公司调研", "行业研究", "估值比较", "风险跟踪"],
  },
  mage: {
    className: "研究学习",
    title: "研究者 · 大法师",
    desc: "适合写论文、做读书笔记、做学术研究、写长篇文章的学者型人格。",
    image: pixelRoleImage("mage"),
    portraitPosition: "center center",
    tags: ["知识归纳", "文献整理", "长上下文"],
    specialty: "研究整理",
    taskFocus: ["论文阅读", "综述写作", "笔记沉淀", "研究设计"],
  },
  summoner: {
    className: "组织管理",
    title: "管理者 · 召唤师",
    desc: "适合招人、开会、管项目、做流程、写制度、推进团队协作。",
    image: pixelRoleImage("summoner"),
    portraitPosition: "center center",
    tags: ["组织编排", "例会纪要", "多人协同"],
    specialty: "流程治理",
    taskFocus: ["招聘管理", "项目推进", "制度输出", "团队复盘"],
  },
  warrior: {
    className: "工程开发",
    title: "技术员 · 战士",
    desc: "适合写代码、改代码、跑测试、查问题、做自动化交付。",
    image: pixelRoleImage("warrior"),
    portraitPosition: "center center",
    tags: ["工程交付", "自动验证", "问题歼灭"],
    specialty: "代码执行",
    taskFocus: ["代码修改", "测试排障", "浏览器调试", "自动化脚本"],
  },
  paladin: {
    className: "增长运营",
    title: "营销者 · 圣骑士",
    desc: "适合内容运营、渠道增长、SEO、投放复盘、客服沟通和客户转化。",
    image: pixelRoleImage("paladin"),
    portraitPosition: "center center",
    tags: ["内容引擎", "增长推进", "客户沟通"],
    specialty: "增长转化",
    taskFocus: ["内容运营", "渠道分析", "营销策划", "客户沟通"],
  },
  archer: {
    className: "设计创意",
    title: "设计师 · 弓箭手",
    desc: "适合做 UI、海报、配图、KV、图像生成、分镜和创意方案。",
    image: pixelRoleImage("archer"),
    portraitPosition: "center center",
    tags: ["视觉创作", "界面塑形", "图像召唤"],
    specialty: "视觉构图",
    taskFocus: ["UI 设计", "海报 KV", "图像生成", "视频分镜"],
  },
};

const ALL_ROLE_IDS = Object.keys(roleProfiles);

const packageDefs = [
  { id: "low", label: "基础默认包", note: "基础执行力，优先装控制、搜索、文档和金融核心技能。" },
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
  { id: "system", label: "系统权限", note: "系统命令与进程。" },
  { id: "file", label: "文件访问", note: "读写工作目录文件。" },
  { id: "web", label: "网页访问", note: "联网搜索与抓取。" },
  { id: "session", label: "会话记忆", note: "引用当前与历史上下文。" },
  { id: "tools", label: "工具调用", note: "联动已安装工具链。" },
];

const slotLabels = {
  head: "头部",
  shoulders: "肩甲",
  core: "项链",
  mainhand: "主手",
  offhand: "副手",
  belt: "腰带",
  legs: "腿位",
  boots: "靴位",
  ring: "戒位",
  chest: "胸部",
};

const slotShortLabels = {
  head: "冠",
  shoulders: "肩",
  core: "链",
  mainhand: "主",
  offhand: "副",
  belt: "带",
  legs: "腿",
  boots: "靴",
  ring: "戒",
  chest: "胸",
};

const toolTypeGlyph = {
  模型: "模",
  MCP: "控",
  Tool: "工",
  App: "应",
  API: "链",
};
const INVENTORY_VISIBLE_TYPES = new Set(["API", "MCP", "Tool"]);
const SKILL_LINK_TOOL_PREFIX = "skill-tool:";

const rarityLabelMap = {
  common: "蓝装",
  magic: "蓝装",
  uncommon: "绿装",
  rare: "紫装",
  mythic: "橙装",
};

const skillRarityOverrides = {
  "nano-pdf": "uncommon",
  brainstorming: "mythic",
  "self-improving-agent-cn": "rare",
  reflection: "rare",
  summarize: "uncommon",
  "skill-creator": "mythic",
  "url-to-markdown": "uncommon",
};

const toolRarityOverrides = {
  "api-minimax-api-key": "rare",
};

const rarityRankMap = {
  common: 1,
  magic: 2,
  uncommon: 3,
  rare: 4,
  mythic: 5,
};

function normalizeRarity(raw, fallback = "magic") {
  const key = String(raw || "").trim().toLowerCase();
  if (rarityRankMap[key]) return key;
  return fallback;
}

function mergedRarity(base, forced) {
  const b = normalizeRarity(base);
  const f = normalizeRarity(forced);
  return (rarityRankMap[f] || 0) >= (rarityRankMap[b] || 0) ? f : b;
}


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
  { id: "MCP", label: "MCP" },
  { id: "Tool", label: "CLI Tool" },
  { id: "API", label: "API" },
];

const skillCatalog = [
  { id: "capability-evolver", name: "Capability Evolver", tier: "low", branch: "控制中枢", desc: "分析运行历史、识别失败模式，并推动代理自我修复和能力进化。", deps: [], roles: ["druid", "summoner"], pack: ["low", "medium", "high"] },
  { id: "openclaw-cron-setup", name: "Cron Setup", tier: "low", branch: "控制中枢", desc: "配置 OpenClaw 内置 Cron 调度器，创建一次性提醒、周期任务和后台自动化。", deps: [], roles: ["druid", "summoner", "warrior"], pack: ["low", "medium", "high"] },
  { id: "proactive-agent", name: "Proactive Agent", tier: "low", branch: "控制中枢", desc: "把 Agent 从被动应答改造成会预判需求、主动跟进和持续改进的协作伙伴。", deps: [], roles: ["druid", "summoner"], pack: ["low", "medium", "high"] },
  { id: "self-improving-agent-cn", name: "Self Improving CN", tier: "low", branch: "控制中枢", desc: "记录错误、用户纠正和最佳实践，沉淀为可跨会话复用的长期记忆。", deps: ["reflection"], roles: ["druid", "mage"], pack: ["low", "medium", "high"] },
  { id: "brainstorming", name: "Brainstorming", tier: "low", branch: "控制中枢", desc: "在创意和改动前先澄清目标、约束和方案，再进入实现。", deps: [], roles: ["mage", "paladin", "archer"], pack: ["low", "medium", "high"] },
  { id: "reflection", name: "Reflection", tier: "low", branch: "控制中枢", desc: "在交付前后做自检、复盘和模式识别，减少重复犯错。", deps: [], roles: ["druid", "mage", "summoner"], pack: ["low", "medium", "high"] },
  { id: "find-skills", name: "Find Skills", tier: "low", branch: "控制中枢", desc: "帮用户从 skills 生态里查找、安装和更新合适的技能。", deps: ["web-search"], roles: ["druid"], pack: ["low", "medium", "high"] },
  { id: "skill-creator", name: "Skill Creator", tier: "low", branch: "控制中枢", desc: "用于设计、编写和迭代新的 Skill，包括结构、说明和工作流。", deps: ["find-skills"], roles: ["warrior", "mage"], pack: ["low", "medium", "high"] },

  { id: "agent-browser", name: "Agent Browser", tier: "low", branch: "执行系统", desc: "使用结构化命令驱动无头浏览器，完成打开、点击、输入和抓取页面。", deps: [], roles: ["warrior", "archer"], pack: ["low", "medium", "high"] },
  { id: "chrome-devtools-mcp", name: "Chrome DevTools MCP", tier: "low", branch: "执行系统", desc: "通过官方 Chrome DevTools MCP 控制浏览器，做调试、抓包、性能和自动化测试。", deps: ["agent-browser"], roles: ["warrior", "archer"], pack: ["low", "medium", "high"] },
  { id: "github", name: "GitHub", tier: "low", branch: "执行系统", desc: "用 gh CLI 读写 GitHub 仓库、PR、Issue 和工作流运行记录。", deps: [], roles: ["warrior", "summoner"], pack: ["low", "medium", "high"] },
  { id: "mcp-builder", name: "MCP Builder", tier: "low", branch: "执行系统", desc: "设计和实现高质量 MCP 服务，把外部 API 封装成可供模型调用的工具。", deps: ["github"], roles: ["warrior"], pack: ["low", "medium", "high"] },
  { id: "model-usage", name: "Model Usage", tier: "low", branch: "执行系统", desc: "汇总本地模型用量和成本，查看当前模型或完整模型分布。", deps: [], roles: ["warrior", "druid"], pack: ["low", "medium", "high"] },
  { id: "shell", name: "Shell", tier: "low", branch: "执行系统", desc: "执行终端命令、脚本、进程管理和文件系统操作。", deps: [], roles: ["warrior", "druid"], pack: ["low", "medium", "high"] },

  { id: "web-search", name: "Web Search", tier: "low", branch: "情报网络", desc: "用 DuckDuckGo 搜索网页、新闻、图片和视频，适合实时信息查询。", deps: [], roles: ["assassin", "paladin", "druid"], pack: ["low", "medium", "high"] },
  { id: "tavily-search", name: "Tavily Search", tier: "low", branch: "情报网络", desc: "使用 Tavily 的 LLM 优化搜索 API 返回结构化结果、摘要片段和元数据。", deps: ["web-search"], roles: ["assassin", "mage"], pack: ["low", "medium", "high"] },
  { id: "minimax-web-search", name: "MiniMax Web Search", tier: "low", branch: "情报网络", desc: "优先走 MiniMax MCP 的联网搜索链路，适合最新资讯和实时资料查询。", deps: ["web-search"], roles: ["druid", "assassin"], pack: ["low", "medium", "high"] },
  { id: "news-radar", name: "News Radar", tier: "low", branch: "情报网络", desc: "聚合国际新闻源，追踪热点、情绪和来源分布。", deps: ["web-search"], roles: ["assassin", "paladin"], pack: ["low", "medium", "high"] },
  { id: "url-to-markdown", name: "URL To Markdown", tier: "low", branch: "情报网络", desc: "通过 Chrome CDP 抓取网页并转换为干净 Markdown，支持登录后页面。", deps: ["web-search"], roles: ["mage", "druid"], pack: ["low", "medium", "high"] },
  { id: "blogwatcher", name: "Blogwatcher", tier: "medium", branch: "情报网络", desc: "用 blogwatcher CLI 监控博客和 RSS/Atom 订阅源更新。", deps: ["news-radar"], roles: ["paladin", "druid"], pack: ["medium", "high"] },

  { id: "pdf", name: "PDF", tier: "low", branch: "知识文档", desc: "提供 PDF 文本/表格提取、合并拆分、创建和表单处理。", deps: [], roles: ["mage", "summoner"], pack: ["low", "medium", "high"] },
  { id: "nano-pdf", name: "Nano PDF", tier: "medium", branch: "知识文档", desc: "用自然语言指令直接修改 PDF 页面内容。", deps: ["pdf"], roles: ["mage"], pack: ["medium", "high"] },
  { id: "docx", name: "Docx", tier: "low", branch: "知识文档", desc: "创建、编辑和分析 Word 文档，支持批注、修订和格式保留。", deps: [], roles: ["summoner", "paladin"], pack: ["low", "medium", "high"] },
  { id: "pptx", name: "PPTX", tier: "low", branch: "知识文档", desc: "创建、编辑和分析 PPT，支持版式、批注和讲稿内容处理。", deps: ["docx"], roles: ["summoner", "paladin", "archer"], pack: ["low", "medium", "high"] },
  { id: "xlsx", name: "XLSX", tier: "low", branch: "知识文档", desc: "创建、编辑和分析电子表格，支持公式、格式和数据建模。", deps: [], roles: ["assassin", "summoner"], pack: ["low", "medium", "high"] },
  { id: "summarize", name: "Summarize", tier: "medium", branch: "知识文档", desc: "用 summarize CLI 压缩 URL、PDF、图片、音频和 YouTube 内容。", deps: ["url-to-markdown"], roles: ["mage", "druid"], pack: ["medium", "high"] },
  { id: "notebooklm-skill", name: "NotebookLM", tier: "medium", branch: "知识文档", desc: "直接查询 Google NotebookLM 笔记库，获得带来源依据的回答。", deps: ["pdf", "summarize"], roles: ["mage"], pack: ["medium", "high"] },
  { id: "agentmail", name: "AgentMail", tier: "medium", branch: "知识文档", desc: "给 Agent 配置独立邮箱，支持收发邮件、附件、标签、草稿和 webhook。", deps: ["docx"], roles: ["druid", "paladin", "summoner"], pack: ["medium", "high"] },

  { id: "stock-monitor-skill", name: "Stock Monitor", tier: "low", branch: "金融引擎", desc: "监控股票价格、均线、RSI、成交量等信号并触发预警。", deps: [], roles: ["assassin"], pack: ["low", "medium", "high"] },
  { id: "multi-search-engine", name: "Multi Search Engine", tier: "low", branch: "金融引擎", desc: "联动 17 个搜索引擎做多源搜索，不依赖 API Key。", deps: ["web-search", "tavily-search"], roles: ["assassin"], pack: ["low", "medium", "high"] },
  { id: "akshare-stock", name: "AkShare Stock", tier: "low", branch: "金融引擎", desc: "基于 AkShare 获取 A 股行情、财务和板块数据，用于量化分析。", deps: ["xlsx"], roles: ["assassin"], pack: ["low", "medium", "high"] },

  { id: "content-strategy", name: "Content Strategy", tier: "medium", branch: "增长工坊", desc: "规划内容策略、主题集群、栏目和选题路线。", deps: ["summarize", "web-search"], roles: ["paladin"], pack: ["medium", "high"] },
  { id: "social-content", name: "Social Content", tier: "medium", branch: "增长工坊", desc: "生成和优化多平台社媒内容、发布节奏和互动策略。", deps: ["content-strategy"], roles: ["paladin"], pack: ["medium", "high"] },
  { id: "marketingskills", name: "Marketing Skills", tier: "high", branch: "增长工坊", desc: "营销技能总入口，用于路由到内容策略和社媒子技能。", deps: ["content-strategy", "social-content"], roles: ["paladin"], pack: ["high"] },
  { id: "baoyu-skills", name: "Baoyu Skills", tier: "high", branch: "增长工坊", desc: "baoyu 内容生产与分发技能总入口，可路由到配图、发文、翻译等子技能。", deps: ["social-content"], roles: ["paladin", "archer"], pack: ["high"] },

  { id: "frontend-design", name: "Frontend Design", tier: "high", branch: "创意工坊", desc: "生成高质量、非模板化的前端界面和页面实现。", deps: [], roles: ["archer", "warrior"], pack: ["high"] },
  { id: "web-design", name: "Web Design", tier: "high", branch: "创意工坊", desc: "按 Web Interface Guidelines 审查 UI/UX、可用性和可访问性问题。", deps: ["frontend-design"], roles: ["archer"], pack: ["high"] },
  { id: "ai-image-generation", name: "AI Image Generation", tier: "medium", branch: "创意工坊", desc: "通过 inference.sh 调用 50+ 模型生成和编辑图片。", deps: [], roles: ["archer"], pack: ["medium", "high"] },
  { id: "gemini-image-service", name: "Gemini Image Service", tier: "medium", branch: "创意工坊", desc: "使用 Gemini 图像接口生成图片，支持自定义代理地址和模型名。", deps: ["ai-image-generation"], roles: ["archer"], pack: ["medium", "high"] },
  { id: "nano-banana-service", name: "Nano Banana Service", tier: "medium", branch: "创意工坊", desc: "使用 Gemini 3 Pro Image（Nano Banana）生成或编辑高分辨率图片。", deps: ["ai-image-generation"], roles: ["archer"], pack: ["medium", "high"] },
  { id: "grok-imagine-1.0-video", name: "Grok Imagine Video", tier: "high", branch: "创意工坊", desc: "调用 grok-imagine-1.0-video 生成短视频和镜头内容。", deps: ["gemini-image-service", "nano-banana-service"], roles: ["archer"], pack: ["high"] },
  { id: "inference-skills", name: "Inference Skills", tier: "high", branch: "创意工坊", desc: "inference.sh 工具技能总入口，当前主要路由到图像生成能力。", deps: ["ai-image-generation"], roles: ["archer"], pack: ["high"] },

  { id: "minimax-image-understanding", name: "MiniMax Image Understanding", tier: "low", branch: "视觉理解", desc: "优先使用 MiniMax 识图工具分析、描述和提取图片信息。", deps: [], roles: ["archer", "warrior"], pack: ["low", "medium", "high"] },
];

const toolCatalog = [
  { id: "minimax-2-7", name: "MiniMax 2.7", type: "模型", rarity: "rare", slot: "chest", desc: "默认主力大模型，平衡速度与质量。", roles: ALL_ROLE_IDS },
  { id: "claude-main", name: "Claude Main", type: "模型", rarity: "mythic", slot: "chest", desc: "长文本、规划与复杂推理。", roles: ["druid", "assassin", "mage", "summoner", "paladin"] },
  { id: "codex-core", name: "Codex Core", type: "模型", rarity: "mythic", slot: "chest", desc: "代码实现、调试与验证。", roles: ["warrior"] },
  { id: "gemini-vision", name: "Gemini Vision", type: "模型", rarity: "mythic", slot: "chest", desc: "多模态理解与图像任务。", roles: ["archer", "mage", "paladin"] },
  { id: "nano-banana", name: "Nano Banana", type: "模型", rarity: "rare", slot: "chest", desc: "视觉创作与人物图生成。", roles: ["archer"] },
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
  { id: "document-forge", name: "Document Forge", type: "Tool", rarity: "magic", slot: "legs", desc: "Docx / PDF / PPTX 输出。", roles: ["mage", "summoner", "paladin"] },
  { id: "sheet-engine", name: "Sheet Engine", type: "Tool", rarity: "magic", slot: "legs", desc: "XLSX 分析与表格建模。", roles: ["assassin", "summoner"] },
  { id: "search-array", name: "Search Array", type: "API", rarity: "magic", slot: "ring", desc: "搜索 API 聚合阵列。", roles: ["druid", "assassin", "paladin"] },
  { id: "tavily-core", name: "Tavily Core", type: "API", rarity: "magic", slot: "ring", desc: "结构化外部搜索接口。", roles: ["assassin", "mage"] },
  { id: "market-radar", name: "Market Radar", type: "API", rarity: "rare", slot: "ring", desc: "新闻雷达与市场情报。", roles: ["assassin", "paladin"] },
  { id: "agentmail-suite", name: "AgentMail Suite", type: "App", rarity: "magic", slot: "shoulders", desc: "邮件往来与客户沟通。", roles: ["druid", "paladin", "summoner"] },
  { id: "video-anvil", name: "Video Anvil", type: "Tool", rarity: "rare", slot: "shoulders", desc: "视频分镜与成片链路。", roles: ["archer"] },
  { id: "cron-orb", name: "Cron Orb", type: "Tool", rarity: "rare", slot: "belt", desc: "定时任务与后台巡检。", roles: ["druid", "summoner", "warrior"] },
  { id: "watchtower-daemon", name: "Watchtower Daemon", type: "Tool", rarity: "magic", slot: "belt", desc: "心跳巡检与异常恢复。", roles: ["druid", "warrior"] },
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
  const queryRole = normalizeRoleIdForUi(params.get("role"));
  if (roleProfiles[queryRole]) return queryRole;
  if (roleProfiles[serverCatalogRole]) return serverCatalogRole;
  const storedRole = normalizeRoleIdForUi(window.localStorage.getItem("openclaw.persona.role"));
  return roleProfiles[storedRole] ? storedRole : defaultRole;
}

function readRequestedTab() {
  const params = new URLSearchParams(window.location.search);
  const tab = params.get("tab");
  return ["skills", "equipment", "status", "tasks", "levels"].includes(tab) ? tab : null;
}

function normalizeWorldUrl(url) {
  try {
    const parsed = new URL(url, window.location.href);
    parsed.pathname = parsed.pathname.replace(/\/+$/, "") || "/";
    return parsed.toString();
  } catch {
    return "";
  }
}

function withRoleParam(url, role) {
  try {
    const parsed = new URL(url, window.location.href);
    if (!parsed.searchParams.has("role")) {
      parsed.searchParams.set("role", role);
    }
    return parsed.toString();
  } catch {
    return url;
  }
}

function readLegacyWorldCandidates() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get("world");
  const fromStorage =
    window.localStorage.getItem("openclaw.runtime.world.url") || window.localStorage.getItem("openclaw.runtime.worldUrl");
  const candidates = [];
  if (fromQuery) {
    candidates.push(fromQuery);
  }
  if (fromStorage) {
    candidates.push(fromStorage);
  }

  const protocol = window.location.protocol?.startsWith("http") ? window.location.protocol : "http:";
  const hostCandidates = [];
  if (window.location.hostname) {
    hostCandidates.push(window.location.hostname);
  }
  if (!hostCandidates.includes("127.0.0.1")) {
    hostCandidates.push("127.0.0.1");
  }
  if (!hostCandidates.includes("localhost")) {
    hostCandidates.push("localhost");
  }

  hostCandidates.forEach((host) => {
    candidates.push(`${protocol}//${host}:${runtimeWorldPort}/`);
  });

  return Array.from(new Set(candidates.map(normalizeWorldUrl).filter(Boolean)));
}

async function isLegacyWorldReachable(baseUrl) {
  const checks = ["status", ""];
  for (const path of checks) {
    try {
      const target = new URL(path, baseUrl).toString();
      const response = await fetch(target, { method: "GET", cache: "no-store", mode: "no-cors" });
      if (response?.type === "opaque" || response?.ok) {
        return true;
      }
    } catch {
      // try next candidate
    }
  }
  return false;
}

async function resolveLegacyWorldUrl(role) {
  const candidates = readLegacyWorldCandidates();
  for (const candidate of candidates) {
    if (await isLegacyWorldReachable(candidate)) {
      return withRoleParam(candidate, role);
    }
  }
  return null;
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

function normalizeRoleIdForUi(roleId) {
  const raw = String(roleId || "").trim().toLowerCase();
  if (raw === "designer") return "archer";
  return raw;
}

function friendlyNameFromId(id) {
  return String(id || "")
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\b\w/g, (ch) => ch.toUpperCase());
}

function inferBranchFromSkillId(skillId) {
  const id = String(skillId || "").toLowerCase();
  if (/search|news|radar|trend|crawl/.test(id)) return "情报网络";
  if (/doc|pdf|ppt|xlsx|notebook|summary|markdown/.test(id)) return "知识文档";
  if (/stock|finance|akshare|quant|fund/.test(id)) return "金融引擎";
  if (/design|image|video|logo|poster|infographic|animation/.test(id)) return "创意工坊";
  if (/content|social|marketing|wechat|xhs|weibo/.test(id)) return "增长工坊";
  if (/browser|devtools|shell|github|mcp|code|test|build/.test(id)) return "执行系统";
  return "控制中枢";
}

function inferSkillDescription(skillId, branch) {
  const id = String(skillId || "").toLowerCase();
  if (/search|news|radar|trend|crawl/.test(id)) return "用于检索网页信息、追踪热点与提取关键情报。";
  if (/doc|pdf|ppt|xlsx|notebook|summary|markdown/.test(id)) return "用于文档处理、摘要整理和知识沉淀。";
  if (/stock|finance|akshare|quant|fund/.test(id)) return "用于行情监控、财务分析与投资研究辅助。";
  if (/design|image|video|logo|poster|infographic|animation/.test(id)) return "用于图像、设计与多媒体内容生成。";
  if (/content|social|marketing|wechat|xhs|weibo/.test(id)) return "用于内容策划、分发运营和渠道增长。";
  if (/browser|devtools|shell|github|mcp|code|test|build/.test(id)) return "用于自动化执行、工程开发与调试验证。";
  if (branchMeta[branch]?.note) return branchMeta[branch].note;
  return "用于扩展当前角色的任务执行能力。";
}

function normalizeSkillDescription(desc, skillId, branch) {
  const text = String(desc || "").trim();
  if (!text || /^来自本地技能仓[:：]/.test(text)) return inferSkillDescription(skillId, branch);
  return text;
}

function normalizeToolType(rawType, name) {
  const t = String(rawType || "").trim();
  if (["模型", "MCP", "Tool", "App", "API"].includes(t)) return t;
  const low = `${t} ${String(name || "")}`.toLowerCase();
  if (/model|模型/.test(low)) return "模型";
  if (/mcp/.test(low)) return "MCP";
  if (/api|key|token/.test(low)) return "API";
  if (/app|calendar|mail|wechat/.test(low)) return "App";
  return "Tool";
}

function normalizeToolSlot(rawSlot, type, name, index = 0) {
  const slot = String(rawSlot || "").trim().toLowerCase();
  if (SLOT_ORDER.includes(slot)) return slot;
  const typeLow = String(type || "").toLowerCase();
  const low = `${typeLow} ${String(name || "")}`.toLowerCase();
  if (typeLow.includes("模型") || typeLow.includes("model")) return "chest";
  if (/api|key|token|search|radar/.test(low)) return index % 2 === 0 ? "ring" : "core";
  if (/mcp|browser|devtools/.test(low)) return index % 2 === 0 ? "mainhand" : "offhand";
  if (/mail|calendar|wechat|app/.test(low)) return "shoulders";
  if (/image|video|design/.test(low)) return index % 2 === 0 ? "offhand" : "legs";
  if (/shell|tool|github/.test(low)) return "belt";
  return "boots";
}
function normalizePopularity(raw) {
  const value = Number(raw);
  return Number.isFinite(value) && value > 0 ? value : 0;
}

function rarityFromPopularity(popularity) {
  if (popularity >= 15000) return "mythic";
  if (popularity >= 7000) return "rare";
  if (popularity >= 3000) return "uncommon";
  return "magic";
}

function rarityLabel(rarity) {
  return rarityLabelMap[rarity] || "蓝装";
}

function skillLinkedToolId(skillId) {
  return `${SKILL_LINK_TOOL_PREFIX}${skillId}`;
}

function isSkillLinkedToolId(id) {
  return String(id || "").startsWith(SKILL_LINK_TOOL_PREFIX);
}

function legacyMappedSkillIdFromToolId(id) {
  const raw = String(id || "");
  if (!raw) return "";
  return raw.replace(/^(tool|app|mcp|api)-/, "");
}

function isLegacySkillMappedTool(tool) {
  if (!tool?.dynamic) return false;
  if (isSkillLinkedToolId(tool.id)) return false;
  const maybeSkillId = legacyMappedSkillIdFromToolId(tool.id);
  if (maybeSkillId && skillById(maybeSkillId)) return true;
  const desc = String(tool.desc || "");
  return /从已安装\s*Skill\s*识别|由技能「.+」自动映射/.test(desc);
}

function isSkillShadowTool(tool) {
  if (!tool?.dynamic) return false;
  if (isSkillLinkedToolId(tool.id)) return false;
  if (skillById(tool.id)) return true;
  return isLegacySkillMappedTool(tool);
}

function isInventoryVisibleTool(tool) {
  return Boolean(tool && INVENTORY_VISIBLE_TYPES.has(tool.type) && !isSkillShadowTool(tool));
}

function classifySkillLinkedToolType(skill) {
  const low = `${String(skill?.id || "")} ${String(skill?.name || "")}`.toLowerCase();
  if (/api|search|weather|finance|stock|akshare|tavily|brave|token|key|openrouter|gemini|minimax/.test(low)) return "API";
  if (/mcp|devtools|browser|github|chrome/.test(low)) return "MCP";
  return "Tool";
}

function inferSkillPopularity(skill) {
  const fromField = normalizePopularity(skill?.popularity || skill?.stars || skill?.downloads || skill?.score);
  if (fromField) return fromField;
  const low = `${String(skill?.id || "")} ${String(skill?.name || "")}`.toLowerCase();
  if (/github|chrome|devtools|tavily|brave|browser|openai|gemini|minimax/.test(low)) return 16000;
  if (/wechat|notebook|pdf|docx|xlsx|pptx|stock|search/.test(low)) return 7000;
  return 2200;
}

function skillLinkedToolName(skill, type) {
  if (type === "API") return `${skill.name} API`;
  if (type === "MCP") return `${skill.name} MCP`;
  return `${skill.name} CLI Tool`;
}

function syncSkillLinkedTools(role, roleState) {
  const enabled = enabledSkillIds(roleState)
    .map((id) => skillById(id))
    .filter(Boolean);
  const staleLegacyIds = new Set(toolCatalog.filter((tool) => isLegacySkillMappedTool(tool)).map((tool) => tool.id));
  const knownToolIds = new Set(toolCatalog.map((item) => item.id));
  const linkedTools = enabled.map((skill, idx) => {
    const type = classifySkillLinkedToolType(skill);
    const popularity = inferSkillPopularity(skill);
    const rarity = mergedRarity(rarityFromPopularity(popularity), skillRarityOverrides[skill.id]);
    const slot = normalizeToolSlot("", type, skill.name, idx);
    const id = skillLinkedToolId(skill.id);
    const tool = {
      id,
      name: skillLinkedToolName(skill, type),
      type,
      rarity,
      popularity,
      slot,
      desc: `由技能「${skill.name}」自动映射的${type === "API" ? "API接口" : type === "MCP" ? "MCP工具" : "CLI工具"}。`,
      roles: Array.isArray(skill.roles) && skill.roles.length ? skill.roles : ALL_ROLE_IDS,
      dynamic: true,
      linkedSkillId: skill.id,
    };
    if (knownToolIds.has(id)) {
      const existing = toolById(id);
      if (existing) Object.assign(existing, tool);
    } else {
      toolCatalog.push(tool);
      knownToolIds.add(id);
    }
    return tool;
  });

  const linkedIds = new Set(linkedTools.map((tool) => tool.id));
  roleState.inventory = (roleState.inventory || []).filter((id) => {
    if (staleLegacyIds.has(id)) return false;
    if (isSkillLinkedToolId(id) && !linkedIds.has(id)) return false;
    return true;
  });

  SLOT_ORDER.forEach((slot) => {
    const equippedId = roleState.equipped?.[slot];
    if (staleLegacyIds.has(equippedId)) {
      roleState.equipped[slot] = null;
      return;
    }
    if (isSkillLinkedToolId(equippedId) && !linkedIds.has(equippedId)) {
      roleState.equipped[slot] = null;
    }
  });

  const sorted = linkedTools
    .slice()
    .sort((a, b) => rarityScore(b.rarity) - rarityScore(a.rarity) || normalizePopularity(b.popularity) - normalizePopularity(a.popularity));
  const assignedSlots = new Set();
  sorted.forEach((tool) => {
    if (assignedSlots.has(tool.slot)) return;
    roleState.equipped[tool.slot] = tool.id;
    assignedSlots.add(tool.slot);
  });

  roleState.inventory = Array.from(new Set([...(roleState.inventory || []), ...linkedTools.map((tool) => tool.id)]));
}


function mergeRemoteCatalogData(payload) {
  const remoteSkillObjects = Array.isArray(payload?.skills?.objects) ? payload.skills.objects : [];
  const remoteInstalled = Array.isArray(payload?.skills?.installed) ? payload.skills.installed : [];
  const remoteAll = Array.isArray(payload?.skills?.all) ? payload.skills.all : [];
  const remoteRole = normalizeRoleIdForUi(payload?.role);

  const mergedSkillIds = new Set([...remoteInstalled, ...remoteAll].map((id) => String(id || "").trim()).filter(Boolean));
  const knownSkillIds = new Set(skillCatalog.map((item) => item.id));

  remoteSkillObjects.forEach((skill) => {
    const id = String(skill?.id || "").trim();
    if (!id || knownSkillIds.has(id)) return;
    const roles = (Array.isArray(skill?.roles) ? skill.roles : ALL_ROLE_IDS)
      .map(normalizeRoleIdForUi)
      .filter((r) => ALL_ROLE_IDS.includes(r));
    skillCatalog.push({
      id,
      name: String(skill?.name || friendlyNameFromId(id)),
      tier: ["low", "medium", "high"].includes(skill?.tier) ? skill.tier : "low",
      branch: String(skill?.branch || inferBranchFromSkillId(id)),
      desc: normalizeSkillDescription(skill?.desc, id, String(skill?.branch || inferBranchFromSkillId(id))),
      deps: Array.isArray(skill?.deps) ? skill.deps.filter(Boolean) : [],
      roles: roles.length ? roles : ALL_ROLE_IDS,
      pack: Array.isArray(skill?.pack) && skill.pack.length ? skill.pack.filter((x) => ["low", "medium", "high"].includes(x)) : ["low", "medium", "high"],
      popularity: normalizePopularity(skill?.popularity || skill?.stars || skill?.downloads || skill?.score),
      defaultInstall: false,
      dynamic: true,
    });
    knownSkillIds.add(id);
  });

  mergedSkillIds.forEach((id) => {
    if (knownSkillIds.has(id)) return;
    skillCatalog.push({
      id,
      name: friendlyNameFromId(id),
      tier: "low",
      branch: inferBranchFromSkillId(id),
      desc: normalizeSkillDescription("", id, inferBranchFromSkillId(id)),
      deps: [],
      roles: ALL_ROLE_IDS,
      pack: ["low", "medium", "high"],
      popularity: 0,
      defaultInstall: false,
      dynamic: true,
    });
    knownSkillIds.add(id);
  });

  const remoteEquipment = Array.isArray(payload?.equipment) ? payload.equipment : [];
  const knownToolIds = new Set(toolCatalog.map((item) => item.id));
  remoteEquipment.forEach((item, idx) => {
    const id = String(item?.id || "").trim();
    if (!id || knownToolIds.has(id)) return;
    const name = String(item?.name || friendlyNameFromId(id));
    const type = normalizeToolType(item?.type, name);
    const roles = (Array.isArray(item?.roles) ? item.roles : ALL_ROLE_IDS)
      .map(normalizeRoleIdForUi)
      .filter((r) => ALL_ROLE_IDS.includes(r));
    const popularity = normalizePopularity(item?.popularity || item?.stars || item?.downloads || item?.score);
    const minimaxApiRarity = type === "API" && /minimax/.test(`${id} ${name}`.toLowerCase()) ? "rare" : "";
    toolCatalog.push({
      id,
      name,
      type,
      rarity: mergedRarity(
        ["common", "magic", "uncommon", "rare", "mythic"].includes(item?.rarity) ? String(item.rarity) : rarityFromPopularity(popularity),
        toolRarityOverrides[id] || minimaxApiRarity,
      ),
      popularity,
      slot: normalizeToolSlot(item?.slot, type, name, idx),
      desc: String(item?.desc || "来自本地已安装工具/模型/API"),
      roles: roles.length ? roles : ALL_ROLE_IDS,
      dynamic: true,
    });
    knownToolIds.add(id);
  });

  if (remoteRole && ALL_ROLE_IDS.includes(remoteRole)) {
    serverCatalogRole = remoteRole;
    currentRole = remoteRole;
  }
}

async function hydrateDynamicCatalog() {
  try {
    const response = await fetch(CATALOG_ENDPOINT, { cache: "no-store" });
    if (!response.ok) return;
    const payload = await response.json();
    if (!payload?.ok) return;
    mergeRemoteCatalogData(payload);
  } catch {
    // fall back to local static catalogs
  }
}

function roleDefaultSkills(role, skillPack) {
  const maxIndex = packageIndex(skillPack);
  return skillCatalog
    .filter((skill) => {
      if (skill.defaultInstall === false) return false;
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
    catalogSeedVersion: 2,
    skillNodeOffsets: {},
    security: ["system", "file", "web", "session"],
    skillFilter: "all",
    branchFocus: "all",
    inventoryFilter: "all",
    inventoryPage: 1,
    stashPage: 1,
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
  merged.inventoryPage = Math.max(1, Number(merged.inventoryPage) || 1);
  merged.stashPage = Math.max(1, Number(merged.stashPage) || 1);
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

function slotShortLabel(id) {
  return slotShortLabels[id] || id.slice(0, 1).toUpperCase();
}

function toolTypeLabel(type) {
  return type === "Tool" ? "CLI Tool" : type;
}

function toolGlyph(tool) {
  return toolTypeGlyph[tool?.type] || (tool?.type ? tool.type.slice(0, 1) : "?");
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
  if (!isInventoryVisibleTool(tool)) return false;
  if (roleState.inventoryFilter === "all") return true;
  if (roleState.inventoryFilter === "equipped") return Object.values(roleState.equipped).includes(tool.id);
  return tool.type === roleState.inventoryFilter;
}

function rarityScore(rarity) {
  return rarityRankMap[normalizeRarity(rarity, "common")] || 1;
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

function buildRuntimeProjection(role, roleState) {
  const activeSynergies = computeActiveSynergies(roleState).map((item) => item.name);
  return {
    version: 1,
    generatedAt: new Date().toISOString(),
    role,
    persona: {
      title: roleProfiles[role].title,
      className: roleProfiles[role].className,
      desc: roleProfiles[role].desc,
      tags: roleProfiles[role].tags,
    },
    build: {
      skillPack: roleState.skillPack,
      tokenRule: roleState.tokenRule,
      modelRoute: roleState.modelRoute,
      security: roleState.security,
      installedSkills: roleState.installedSkills,
      hotbar: roleState.hotbar.filter(Boolean),
      pinnedSkills: roleState.pinnedSkills.filter(Boolean),
      equipped: roleState.equipped,
      inventory: roleState.inventory,
      activeSynergies,
    },
    runtime: {
      state: "idle",
      detail: "运行世界初始化完成，等待任务。",
      progress: 0,
      source: "profile",
      updatedAt: new Date().toISOString(),
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
  document.body.dataset.mode = tabId;
  try {
    const url = new URL(window.location.href);
    url.searchParams.set("tab", tabId);
    window.history.replaceState({}, "", url.toString());
  } catch {
    // ignore malformed location updates in preview mode
  }
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

function ownedToolIds(roleState) {
  return roleState.inventory.map((id) => toolById(id)).filter(Boolean).map((tool) => tool.id);
}

function bagItemsForRole(role, roleState) {
  return roleState.inventory.map((id) => toolById(id)).filter((tool) => tool && tool.roles.includes(role) && toolMatchesFilter(tool, roleState));
}

const OFFICE_PLAQUE_STORAGE_KEY = "officePlaqueCustomTitle";
const STATUS_ENDPOINT = "/status";
const STATUS_SUMMARY_ENDPOINT = "/openclaw/status/summary";
const APPLY_CONFIG_ENDPOINT = "/openclaw/config/apply";
const DIAGNOSE_ENDPOINT = "/openclaw/diagnose";
const CATALOG_ENDPOINT = "/openclaw/catalog";
const VALID_TABS = ["role", "skills", "equipment", "status", "tasks"];
const TAB_SAVE_STATUS_IDS = {
  role: "tabSaveStatusRole",
  skills: "tabSaveStatusSkills",
  equipment: "tabSaveStatusEquipment",
  status: "tabSaveStatusStatus",
  tasks: "tabSaveStatusTasks",
};
const stateLabelMap = {
  idle: "待命",
  writing: "工作中",
  researching: "检索中",
  executing: "执行中",
  syncing: "同步中",
  error: "报警中",
};

let currentRole = defaultRole;
let currentRoleState = null;
let previewRole = defaultRole;
let pendingRoleChange = null;
let currentRuntime = { state: "idle", detail: "等待任务", progress: 0, updatedAt: "-" };
let currentStatusSummary = null;
let currentIdentity = readIdentityProfile();
let selectedSkillId = null;
let selectedToolId = null;
let statusDiagBusy = false;

function readRequestedTab() {
  const params = new URLSearchParams(window.location.search);
  const tab = params.get("tab") || params.get("mode");
  if (tab === "levels") return "status";
  return VALID_TABS.includes(tab) ? tab : null;
}

function safeParseJson(value, fallback) {
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function normalizeIdentityProfile(raw = {}) {
  const data = raw && typeof raw === "object" ? raw : {};
  const pick = (key, maxLen) => String(data[key] || "").trim().slice(0, maxLen);
  return {
    assistantName: pick("assistantName", 80) || identityDefaults.assistantName,
    userName: pick("userName", 64) || identityDefaults.userName,
    region: pick("region", 64) || identityDefaults.region,
    timezone: pick("timezone", 64) || identityDefaults.timezone,
    goal: pick("goal", 300) || identityDefaults.goal,
    personality: pick("personality", 200) || identityDefaults.personality,
    workStyle: pick("workStyle", 200) || identityDefaults.workStyle,
  };
}

function readIdentityProfile() {
  return normalizeIdentityProfile(safeParseJson(window.localStorage.getItem(identityKey), identityDefaults));
}

function writeIdentityProfile(profile) {
  const normalized = normalizeIdentityProfile(profile);
  window.localStorage.setItem(identityKey, JSON.stringify(normalized));
  return normalized;
}

function normalizeRuntime(payload) {
  if (!payload || typeof payload !== "object") {
    return { state: "idle", detail: "等待任务", progress: 0, updatedAt: "-" };
  }
  return {
    state: String(payload.state || payload.status || "idle").toLowerCase(),
    detail: String(payload.detail || payload.message || payload.text || "等待任务"),
    progress: Math.max(0, Math.min(100, Number(payload.progress || 0))),
    updatedAt: String(payload.updatedAt || payload.updated_at || "-"),
  };
}

function defaultOfficeNameForRole(role) {
  return `${roleProfiles[role]?.title || role}的办公室`;
}

function normalizeOfficePlaqueCandidate(value) {
  return String(value || "")
    .replace(/[“”"']/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function sanitizeOfficePlaqueTitle(value, role = currentRole) {
  const fallback = defaultOfficeNameForRole(role);
  const normalized = normalizeOfficePlaqueCandidate(value);
  if (!normalized) {
    return fallback;
  }
  const asciiCount = (normalized.match(/[A-Za-z]/g) || []).length;
  const mostlyAscii = asciiCount > 0 && asciiCount / normalized.length > 0.45;
  const suspiciousPrompt = [
    /pick something you like/i,
    /\boffice\s*(name|title|plaque)?\b/i,
    /\bplaceholder\b/i,
    /\bchoose\b.*\bname\b/i,
    /\benter\b.*\boffice\b/i,
    /\bdefault\b/i,
  ].some((pattern) => pattern.test(normalized));
  const suspiciousTemplate = /{{|}}|<[^>]+>|[{}[\]]/.test(normalized);
  const suspiciousParen = /[()（）]/.test(normalized) && mostlyAscii;
  const suspiciousLength = normalized.length > 32 && mostlyAscii;
  if (suspiciousPrompt || suspiciousTemplate || suspiciousParen || suspiciousLength) {
    return fallback;
  }
  return normalized;
}

function isRoleDefaultOfficeName(name) {
  const normalized = normalizeOfficePlaqueCandidate(name);
  return Object.keys(roleProfiles).some((role) => normalized === defaultOfficeNameForRole(role));
}

function readOfficeName(role = currentRole) {
  const raw = window.localStorage.getItem(OFFICE_PLAQUE_STORAGE_KEY);
  const sanitized = sanitizeOfficePlaqueTitle(raw, role);
  const normalized = normalizeOfficePlaqueCandidate(raw);
  if (!normalized || sanitized === defaultOfficeNameForRole(role)) {
    window.localStorage.removeItem(OFFICE_PLAQUE_STORAGE_KEY);
  } else if (normalized !== sanitized) {
    window.localStorage.setItem(OFFICE_PLAQUE_STORAGE_KEY, sanitized);
  }
  return sanitized;
}

function writeOfficeName(name, role = currentRole) {
  const sanitized = sanitizeOfficePlaqueTitle(name, role);
  if (!sanitized || sanitized === defaultOfficeNameForRole(role)) {
    window.localStorage.removeItem(OFFICE_PLAQUE_STORAGE_KEY);
    return;
  }
  window.localStorage.setItem(OFFICE_PLAQUE_STORAGE_KEY, sanitized);
}

function enabledSkillIds(roleState) {
  const disabled = new Set(roleState.disabledSkills || []);
  return roleState.installedSkills.filter((id) => !disabled.has(id));
}

function mergeInventory(role, roleState) {
  const defaults = roleDefaultTools(role);
  const roleTools = toolCatalog.filter((tool) => tool.roles.includes(role)).map((tool) => tool.id);
  return Array.from(
    new Set([...(roleState.inventory || []), ...(roleState.stash || []), ...defaults, ...roleTools].filter((id) => toolById(id))),
  );
}

function hydrateRoleState(role, roleState) {
  const merged = normalizeRoleState(role, roleState);
  const installedDynamicCount = merged.installedSkills.filter((id) => skillById(id)?.dynamic).length;
  if (
    merged.installedSkills.length >= 80 &&
    installedDynamicCount / Math.max(1, merged.installedSkills.length) >= 0.70 &&
    Number(roleState?.catalogSeedVersion || 0) < 2
  ) {
    merged.installedSkills = roleDefaultSkills(role, merged.skillPack);
    merged.disabledSkills = [];
  }
  merged.catalogSeedVersion = 2;
  const legacySlotMap = { relic: "legs", network: "ring", companion: "shoulders", automation: "belt" };
  Object.entries(legacySlotMap).forEach(([legacySlot, nextSlot]) => {
    const legacyToolId = roleState?.equipped?.[legacySlot];
    if (legacyToolId && !merged.equipped[nextSlot]) {
      merged.equipped[nextSlot] = legacyToolId;
    }
  });
  merged.activeTab = VALID_TABS.includes(merged.activeTab) ? merged.activeTab : "role";
  merged.disabledSkills = Array.from(
    new Set((merged.disabledSkills || []).filter((id) => merged.installedSkills.includes(id))),
  );
  SLOT_ORDER.forEach((slot) => {
    const equippedId = merged.equipped?.[slot];
    if (!equippedId) return;
    const tool = toolById(equippedId);
    if (!tool || tool.slot !== slot) {
      merged.equipped[slot] = null;
    }
  });
  if (!merged.equipped.chest) {
    const defaultChestTool = roleDefaultTools(role)
      .map((id) => toolById(id))
      .find((tool) => tool && tool.slot === "chest");
    if (defaultChestTool) {
      merged.equipped.chest = defaultChestTool.id;
    }
  }
  syncSkillLinkedTools(role, merged);
  merged.inventory = mergeInventory(role, merged);
  merged.stash = [];
  merged.hotbar = Array.from({ length: HOTBAR_SIZE }, (_, index) => enabledSkillIds(merged)[index] || null);
  if (!merged.selectedSkillId || !merged.installedSkills.includes(merged.selectedSkillId)) {
    merged.selectedSkillId = merged.installedSkills[0] || null;
  }
  const visibleToolIds = merged.inventory.map((id) => toolById(id)).filter(isInventoryVisibleTool).map((tool) => tool.id);
  const equippedToolIds = Object.values(merged.equipped).filter(Boolean);
  if (!merged.selectedToolId || (!visibleToolIds.includes(merged.selectedToolId) && !equippedToolIds.includes(merged.selectedToolId))) {
    merged.selectedToolId = visibleToolIds[0] || equippedToolIds[0] || null;
  }
  return merged;
}

function syncProjection() {
  window.localStorage.setItem(runtimeProjectionKey, JSON.stringify(buildRuntimeProjection(currentRole, currentRoleState)));
}

function persistCurrentRoleState() {
  currentRoleState = hydrateRoleState(currentRole, currentRoleState);
  persistRoleState(currentRole, currentRoleState);
  syncProjection();
}

function setText(id, text) {
  const el = document.getElementById(id);
  if (el) el.textContent = text;
}

function setImage(id, src, alt) {
  const el = document.getElementById(id);
  if (!el) return;
  el.src = src;
  if (alt) el.alt = alt;
}

function setSaveStatus(scope, message) {
  const targetId = TAB_SAVE_STATUS_IDS[scope];
  if (!targetId) return;
  const el = document.getElementById(targetId);
  if (!el) return;
  el.textContent = message;
}

function markCurrentTabDirty() {
  const scope = VALID_TABS.includes(currentRoleState?.activeTab) ? currentRoleState.activeTab : "role";
  setSaveStatus(scope, "待保存");
}

function collectApplyPayload(scope) {
  return {
    scope,
    role: currentRole,
    officeName: readOfficeName(currentRole),
    roleState: deepClone(currentRoleState),
    identity: deepClone(currentIdentity),
  };
}

async function applyRoleStateToBackend(scope, sourceButton) {
  const button = sourceButton || null;
  const originalText = button ? button.textContent : "";
  if (button) {
    button.disabled = true;
    button.textContent = "保存中...";
  }
  setSaveStatus(scope, "保存中...");
  try {
    const response = await fetch(APPLY_CONFIG_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(collectApplyPayload(scope)),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || !result?.ok) {
      throw new Error(result?.msg || `HTTP ${response.status}`);
    }
    if (result.summary && typeof result.summary === "object") {
      currentStatusSummary = result.summary;
      if (result.summary.identity && typeof result.summary.identity === "object") {
        currentIdentity = writeIdentityProfile({ ...currentIdentity, ...result.summary.identity });
      }
    }
    setSaveStatus(scope, `已保存 ${new Date().toLocaleTimeString()}`);
    renderStatusTab();
    return true;
  } catch (error) {
    setSaveStatus(scope, `保存失败: ${error.message}`);
    return false;
  } finally {
    if (button) {
      button.disabled = false;
      button.textContent = originalText || "保存";
    }
  }
}


function renderSummaryStrip() {}

function stateForRole(role) {
  if (role === currentRole) return currentRoleState;
  return hydrateRoleState(role, loadRoleState(role));
}

function renderBanner() {
  const profile = roleProfiles[currentRole];
  const enabledCount = enabledSkillIds(currentRoleState).length;
  const equippedCount = Object.values(currentRoleState.equipped).filter(Boolean).length;
  setText("bannerOfficeTitle", readOfficeName(currentRole));
  setText("bannerOfficeMeta", `${profile.className} · 当前生效职业配置`);
  setText("bannerRoleTitle", profile.title);
  setText("bannerBuildStat", `${enabledCount} 技能 / ${equippedCount} 装备`);
  setText("bannerRouteStat", optionLabel(modelRoutes, currentRoleState.modelRoute).replace(/路由$/, ""));
  setText("bannerRuleStat", `${tierChinese(currentRoleState.tokenRule)}规则 · ${tierChinese(currentRoleState.skillPack)}技能包`);
}

function renderIdentityForm() {
  const map = {
    identityAssistantNameInput: "assistantName",
    identityUserNameInput: "userName",
    identityRegionInput: "region",
    identityTimezoneInput: "timezone",
    identityGoalInput: "goal",
    identityPersonalityInput: "personality",
    identityWorkStyleInput: "workStyle",
  };
  Object.entries(map).forEach(([id, key]) => {
    const el = document.getElementById(id);
    if (!el) return;
    if (document.activeElement === el) return;
    el.value = currentIdentity[key] || identityDefaults[key] || "";
  });
}

function renderRoleTab() {
  const profile = roleProfiles[previewRole];
  const previewRoleState = stateForRole(previewRole);
  const personaGrid = document.getElementById("personaGrid");
  if (personaGrid) {
    personaGrid.innerHTML = Object.entries(roleProfiles)
      .map(
        ([roleId, item]) => `
          <article class="persona-tile ${roleId === previewRole ? "active" : ""} ${roleId === currentRole ? "current" : ""}" data-role="${roleId}">
            <img src="${item.image}" alt="${item.title}" />
            <strong>${item.title}</strong>
            <span>${item.className}</span>
            <em>${roleId === currentRole ? "当前" : roleId === previewRole ? "预览" : "查看"}</em>
          </article>`,
      )
      .join("");
    personaGrid.querySelectorAll(".persona-tile").forEach((tile) => {
      tile.addEventListener("click", () => previewRoleSelection(tile.dataset.role));
    });
  }

  setImage("rolePortrait", profile.image, profile.title);
  setText("roleDetailClass", profile.className);
  setText("roleDetailTitle", profile.title);
  setText("roleDetailDesc", profile.desc);
  setText("roleDetailHeading", previewRole === currentRole ? "当前职业" : "转职预览");
  setText("roleDetailRoute", optionLabel(modelRoutes, previewRoleState.modelRoute).replace(/路由$/, ""));
  setText("roleDetailPack", optionLabel(packageDefs, previewRoleState.skillPack));
  setText("roleDetailFocus", profile.taskFocus.join(" / "));

  const tags = document.getElementById("roleDetailTags");
  if (tags) {
    tags.innerHTML = profile.tags.map((tag) => `<span class="tag-chip">${tag}</span>`).join("");
  }

  const confirmRoleChangeBtn = document.getElementById("confirmRoleChangeBtn");
  if (confirmRoleChangeBtn) {
    confirmRoleChangeBtn.disabled = previewRole === currentRole;
    confirmRoleChangeBtn.textContent = previewRole === currentRole ? "当前职业已生效" : `确认转职为 ${profile.title}`;
  }

  const officeInput = document.getElementById("officeNameInput");
  if (officeInput && document.activeElement !== officeInput) {
    officeInput.value = readOfficeName(currentRole);
  }

  renderIdentityForm();
  renderRoleConfigSummary();
  renderSecurityOptions();
}

function renderOptionCards(target, options, selectedId, onSelect) {
  if (!target) return;
  target.innerHTML = options
    .map(
      (option) => `
        <article class="option-card ${option.id === selectedId ? "active" : ""}" data-option="${option.id}">
          <header>
            <strong>${option.label}</strong>
            <small>${option.note}</small>
          </header>
          <button type="button">${option.id === selectedId ? "当前使用" : "切换"}</button>
        </article>`,
    )
    .join("");
  target.querySelectorAll(".option-card").forEach((card) => {
    card.addEventListener("click", () => onSelect(card.dataset.option));
    card.querySelector("button")?.addEventListener("click", (event) => {
      event.stopPropagation();
      onSelect(card.dataset.option);
    });
  });
}

function renderRoleConfigSummary() {
  const target = document.getElementById("roleConfigSummary");
  if (!target) return;
  const cards = [
    { label: "当前模型路由", value: optionLabel(modelRoutes, currentRoleState.modelRoute).replace(/路由$/, ""), note: "按安装配置生效" },
    { label: "当前规则档位", value: optionLabel(tokenRules, currentRoleState.tokenRule), note: "页面内只读" },
    { label: "当前技能包", value: optionLabel(packageDefs, currentRoleState.skillPack), note: "随职业基线刷新" },
  ];
  target.innerHTML = cards
    .map(
      (item) => `
        <article class="config-readonly-card">
          <span>${item.label}</span>
          <strong>${item.value}</strong>
          <small>${item.note}</small>
        </article>`,
    )
    .join("");
}

function renderSecurityOptions() {
  const target = document.getElementById("securityOptions");
  if (!target) return;
  target.innerHTML = securityOptions
    .map(
      (option) => `
        <article class="security-toggle ${currentRoleState.security.includes(option.id) ? "active" : ""}" data-security="${option.id}">
          <header>
            <strong>${option.label}</strong>
            <small>${option.note}</small>
          </header>
          <span class="security-pill">${currentRoleState.security.includes(option.id) ? "已开放" : "未开放"}</span>
        </article>`,
    )
    .join("");
  target.querySelectorAll(".security-toggle").forEach((card) => {
    card.addEventListener("click", () => {
      const id = card.dataset.security;
      if (currentRoleState.security.includes(id)) {
        currentRoleState.security = currentRoleState.security.filter((item) => item !== id);
      } else {
        currentRoleState.security = [...currentRoleState.security, id];
      }
      commitAndRender();
    });
  });
}

function previewRoleSelection(role) {
  if (!roleProfiles[role]) return;
  previewRole = role;
  renderRoleTab();
}

function openRoleConfirmModal() {
  if (!pendingRoleChange || !roleProfiles[pendingRoleChange]) return;
  const modal = document.getElementById("roleConfirmModal");
  const body = document.getElementById("roleConfirmBody");
  if (body) {
    body.textContent = `你即将从 ${roleProfiles[currentRole].title} 转职为 ${roleProfiles[pendingRoleChange].title}。转职后，部分自定义配置、已安装技能和装备映射可能会被删除或替换。`;
  }
  if (modal) {
    modal.hidden = false;
    document.body.classList.add("modal-open");
  }
}

function closeRoleConfirmModal() {
  const modal = document.getElementById("roleConfirmModal");
  if (modal) modal.hidden = true;
  document.body.classList.remove("modal-open");
}

function applyRoleChange() {
  const role = pendingRoleChange;
  if (!roleProfiles[role] || role === currentRole) {
    closeRoleConfirmModal();
    return;
  }
  const currentOfficeName = readOfficeName(currentRole);
  if (!currentOfficeName || isRoleDefaultOfficeName(currentOfficeName)) {
    writeOfficeName(defaultOfficeNameForRole(role), role);
  }
  currentRole = role;
  previewRole = role;
  pendingRoleChange = null;
  window.localStorage.setItem("openclaw.persona.role", role);
  currentRoleState = hydrateRoleState(role, loadRoleState(role));
  currentRoleState.activeTab = "role";
  selectedSkillId = currentRoleState.selectedSkillId;
  selectedToolId = currentRoleState.selectedToolId;
  currentIdentity = readIdentityProfile();
  closeRoleConfirmModal();
  commitAndRender();
}

function buildSkillInspectorMarkup(skill) {
  if (!skill) {
    return `
      <strong>未选择技能</strong>
      <p>点击左侧技能方块后，这里会显示技能说明、依赖和适用职业。</p>`;
  }
  const installed = currentRoleState.installedSkills.includes(skill.id);
  const disabled = currentRoleState.disabledSkills.includes(skill.id);
  const deps = skill.deps.length ? skill.deps.map((id) => skillById(id)?.name || id) : ["无依赖"];
  return `
    <strong>${skill.name}</strong>
    <p>${skill.desc}</p>
    <ul>
      <li>分支：${skill.branch}</li>
      <li>状态：${installed ? (disabled ? "已安装 / 已停用" : "已安装 / 已启用") : "未安装"}</li>
      <li>依赖：${deps.join("、")}</li>
      <li>适配职业：${skill.roles.map((role) => roleProfiles[role]?.className || role).join("、")}</li>
    </ul>`;
}

function renderSkillsTab() {
  const installedTarget = document.getElementById("installedSkillGrid");
  const inspectorTarget = document.getElementById("skillInspector");
  const installedSkills = currentRoleState.installedSkills.map((id) => skillById(id)).filter(Boolean);
  if (!selectedSkillId || !currentRoleState.installedSkills.includes(selectedSkillId)) {
    selectedSkillId = currentRoleState.installedSkills[0] || null;
  }
  const selectedSkill = skillById(selectedSkillId);

  if (installedTarget) {
    installedTarget.innerHTML = installedSkills.length
      ? installedSkills
          .map((skill) => {
            const disabled = currentRoleState.disabledSkills.includes(skill.id);
            return `
              <article class="skill-tile ${selectedSkillId === skill.id ? "selected" : ""} ${disabled ? "is-disabled" : "is-enabled"}" data-skill="${skill.id}">
                <header>
                  <strong>${skill.name}</strong>
                  <span class="skill-state">${skill.branch}</span>
                </header>
                <p>${skill.desc}</p>
                <div class="skill-actions">
                  <button type="button" class="skill-action ${disabled ? "off" : "on"}" data-action="toggle">${disabled ? "已停用" : "已启用"}</button>
                  <button type="button" class="skill-action secondary" data-action="remove">删除</button>
                </div>
              </article>`;
          })
          .join("")
      : `<article class="skill-tile"><strong>当前没有已安装技能</strong><p>请从下方备选技能库中加入所需能力。</p></article>`;

    installedTarget.querySelectorAll(".skill-tile").forEach((tile) => {
      tile.addEventListener("click", () => {
        selectedSkillId = tile.dataset.skill;
        renderSkillsTab();
      });
      tile.querySelectorAll("[data-action]").forEach((button) => {
        button.addEventListener("click", (event) => {
          event.stopPropagation();
          const skillId = tile.dataset.skill;
          if (button.dataset.action === "toggle") {
            toggleSkillEnabled(skillId);
            return;
          }
          removeSkill(skillId);
        });
      });
    });
  }

  if (inspectorTarget) {
    inspectorTarget.innerHTML = buildSkillInspectorMarkup(selectedSkill);
  }

  const recommended = new Set(recommendedSkillIds(currentRole));
  const libraryTarget = document.getElementById("skillLibraryGrid");
  if (libraryTarget) {
    const library = skillCatalog
      .filter((skill) => !currentRoleState.installedSkills.includes(skill.id))
      .filter((skill) => skill.roles.length === 0 || skill.roles.includes(currentRole) || recommended.has(skill.id))
      .sort((a, b) => {
        const recommendedDelta = Number(recommended.has(b.id)) - Number(recommended.has(a.id));
        if (recommendedDelta) return recommendedDelta;
        const tierDelta = packageIndex(a.tier) - packageIndex(b.tier);
        if (tierDelta) return tierDelta;
        return a.name.localeCompare(b.name, "zh-CN");
      });

    if (!library.length) {
      libraryTarget.innerHTML = `<article class="skill-tile"><strong>暂无可添加技能</strong><p>当前角色已装满本地可识别技能。可先切换职业或从配置菜单安装更多技能包。</p></article>`;
    } else {
      libraryTarget.innerHTML = library
        .map(
          (skill) => `
            <article class="skill-tile" data-library-skill="${skill.id}">
              <header>
                <strong>${skill.name}</strong>
                <span class="skill-state">${recommended.has(skill.id) ? "推荐" : "可添加"}</span>
              </header>
              <p>${skill.desc}</p>
              <div class="skill-actions">
                <button type="button" class="skill-action" data-action="add">添加</button>
              </div>
            </article>`,
        )
        .join("");
    }

    libraryTarget.querySelectorAll("[data-library-skill]").forEach((tile) => {
      tile.addEventListener("click", () => {
        selectedSkillId = tile.dataset.librarySkill;
        renderSkillsTab();
      });
      tile.querySelector("[data-action='add']")?.addEventListener("click", (event) => {
        event.stopPropagation();
        addSkill(tile.dataset.librarySkill);
      });
    });
  }

  renderSkillPackSummary();
}

function renderSkillPackSummary() {
  const target = document.getElementById("skillPackSummary");
  if (!target) return;
  target.innerHTML = [
    { label: "当前技能包", value: optionLabel(packageDefs, currentRoleState.skillPack), note: "跟随订阅套餐自动切换" },
    { label: "当前基线", value: `${currentRoleState.installedSkills.length} 项技能`, note: "由职业和套餐共同决定" },
  ]
    .map(
      (item) => `
        <article class="config-readonly-card">
          <span>${item.label}</span>
          <strong>${item.value}</strong>
          <small>${item.note}</small>
        </article>`,
    )
    .join("");
}

function toggleSkillEnabled(skillId) {
  if (!currentRoleState.installedSkills.includes(skillId)) return;
  if (currentRoleState.disabledSkills.includes(skillId)) {
    currentRoleState.disabledSkills = currentRoleState.disabledSkills.filter((id) => id !== skillId);
  } else {
    currentRoleState.disabledSkills = [...currentRoleState.disabledSkills, skillId];
  }
  commitAndRender();
}

function removeSkill(skillId) {
  currentRoleState.installedSkills = currentRoleState.installedSkills.filter((id) => id !== skillId);
  currentRoleState.disabledSkills = currentRoleState.disabledSkills.filter((id) => id !== skillId);
  selectedSkillId = currentRoleState.installedSkills[0] || null;
  commitAndRender();
}

function addSkill(skillId) {
  if (currentRoleState.installedSkills.includes(skillId)) return;
  currentRoleState.installedSkills = [...currentRoleState.installedSkills, skillId];
  selectedSkillId = skillId;
  commitAndRender();
}

function buildToolInspectorMarkup(tool) {
  if (!tool) {
    return `
      <strong>未选择物品</strong>
      <p>点击下方物品栏中的方块后，这里会显示用途、槽位和套装说明。</p>`;
  }
  return `
    <strong>${tool.name}</strong>
    <p>${tool.desc}</p>
    <div class="stack-list">
      <article>
        <span>类型</span>
        <strong>${toolTypeLabel(tool.type)}</strong>
        <p>稀有度：${rarityLabel(tool.rarity)} · 热度：${Math.round(normalizePopularity(tool.popularity || 0))}</p>
      </article>
      <article>
        <span>装备槽位</span>
        <strong>${slotLabel(tool.slot)}</strong>
        <p>选中物品后，点击对应部位即可装配。</p>
      </article>
      <article>
        <span>适配职业</span>
        <strong>${tool.roles.map((role) => roleProfiles[role]?.className || role).join("、")}</strong>
        <p>用于当前职业时，会参与联动与成长计算。</p>
      </article>
    </div>`;
}

function renderEquipmentTab() {
  setImage("equipmentPortrait", roleProfiles[currentRole].image, roleProfiles[currentRole].title);
  const activeSynergies = computeActiveSynergies(currentRoleState);
  const synergyTarget = document.getElementById("equipmentSynergyList");
  if (synergyTarget) {
    synergyTarget.innerHTML = (activeSynergies.length ? activeSynergies : recommendedSynergiesForRole(currentRole).slice(0, 3))
      .map(
        (entry) => `
          <article>
            <span>${activeSynergies.some((item) => item.id === entry.id) ? "已激活" : "待成型"}</span>
            <strong>${entry.name}</strong>
            <p>${entry.note}</p>
          </article>`,
      )
      .join("");
  }

  const visibleTools = currentRoleState.inventory
    .map((id) => toolById(id))
    .filter((tool) => tool && tool.roles.includes(currentRole) && toolMatchesFilter(tool, currentRoleState))
    .sort(
      (a, b) =>
        rarityScore(b.rarity) - rarityScore(a.rarity) ||
        normalizePopularity(b.popularity) - normalizePopularity(a.popularity) ||
        a.name.localeCompare(b.name, "zh-CN"),
    );

  const visibleToolIds = new Set(visibleTools.map((tool) => tool.id));
  const equippedToolIds = new Set(Object.values(currentRoleState.equipped).filter(Boolean));
  if (!selectedToolId || (!visibleToolIds.has(selectedToolId) && !equippedToolIds.has(selectedToolId))) {
    selectedToolId = visibleTools[0]?.id || Array.from(equippedToolIds)[0] || null;
  }
  currentRoleState.selectedToolId = selectedToolId;
  const selectedTool = toolById(selectedToolId);

  const slotTarget = document.getElementById("equipmentSlots");
  if (slotTarget) {
    slotTarget.innerHTML = SLOT_ORDER.map((slot) => {
      const equippedTool = toolById(currentRoleState.equipped[slot]);
      const selectable = selectedTool && selectedTool.slot === slot;
      return `
        <article class="equipment-slot ${SLOT_POSITION_CLASS[slot] || ""} ${selectable ? "selected" : ""} ${equippedTool ? "equipped" : "empty"} ${equippedTool ? `rarity-${equippedTool.rarity || "magic"}` : ""}" data-slot="${slot}">
          <em>${slotShortLabel(slot)}</em>
          <strong>${slotLabel(slot)}</strong>
          ${equippedTool ? `<span class="rarity-chip rarity-${equippedTool.rarity || "magic"}">${rarityLabel(equippedTool.rarity)}</span>` : ""}
          <p>${equippedTool ? equippedTool.name : "当前未装备"}</p>
          <button type="button">${selectable ? "装配" : equippedTool ? "卸下" : "空槽"}</button>
        </article>`;
    }).join("");
    slotTarget.querySelectorAll(".equipment-slot").forEach((card) => {
      card.addEventListener("click", () => inspectSlot(card.dataset.slot));
      card.querySelector("button")?.addEventListener("click", (event) => {
        event.stopPropagation();
        handleSlotAction(card.dataset.slot);
      });
    });
  }

  const inventoryTarget = document.getElementById("inventoryGrid");
  if (inventoryTarget) {
    inventoryTarget.innerHTML = visibleTools
      .map(
        (tool) => `
          <article class="inventory-tile ${selectedToolId === tool.id ? "selected" : ""} rarity-${tool.rarity || "magic"}" data-tool="${tool.id}">
            <header>
              <span class="glyph">${toolGlyph(tool)}</span>
              <div class="inventory-tags">
                <span class="skill-state">${toolTypeLabel(tool.type)}</span>
                <span class="rarity-chip rarity-${tool.rarity || "magic"}">${rarityLabel(tool.rarity)}</span>
              </div>
            </header>
            <strong>${tool.name}</strong>
            <p>${tool.desc}</p>
            <div class="inventory-actions">
              <button type="button">${selectedToolId === tool.id ? "已选中" : "选中"}</button>
            </div>
          </article>`,
      )
      .join("");
    inventoryTarget.querySelectorAll(".inventory-tile").forEach((tile) => {
      tile.addEventListener("click", () => {
        selectedToolId = tile.dataset.tool;
        currentRoleState.selectedToolId = selectedToolId;
        renderEquipmentTab();
      });
      tile.querySelector("button")?.addEventListener("click", (event) => {
        event.stopPropagation();
        selectedToolId = tile.dataset.tool;
        currentRoleState.selectedToolId = selectedToolId;
        renderEquipmentTab();
      });
    });
  }

  const inspectorTarget = document.getElementById("toolInspector");
  if (inspectorTarget) {
    inspectorTarget.innerHTML = buildToolInspectorMarkup(selectedTool);
  }
}

function inspectSlot(slot) {
  const equippedId = currentRoleState.equipped[slot];
  if (!equippedId) return;
  selectedToolId = equippedId;
  currentRoleState.selectedToolId = selectedToolId;
  renderEquipmentTab();
}

function handleSlotAction(slot) {
  const selectedTool = toolById(selectedToolId);
  if (selectedTool && selectedTool.slot === slot) {
    SLOT_ORDER.forEach((slotId) => {
      if (currentRoleState.equipped[slotId] === selectedTool.id) {
        currentRoleState.equipped[slotId] = null;
      }
    });
    currentRoleState.equipped[slot] = selectedTool.id;
    commitAndRender(false);
    renderEquipmentTab();
    renderStatusTab();
    return;
  }
  currentRoleState.equipped[slot] = null;
  commitAndRender(false);
  renderEquipmentTab();
  renderStatusTab();
}

function renderStatusTab() {
  const localLevel = computeLevel(currentRoleState);
  const summary = currentStatusSummary || {};

  const runtimeLabel = stateLabelMap[currentRuntime.state] || currentRuntime.state;
  setText("statusRuntimeLabel", runtimeLabel);
  setText("statusRuntimeDetail", currentRuntime.detail);
  const progressFill = document.getElementById("statusProgressFill");
  if (progressFill) progressFill.style.width = `${currentRuntime.progress}%`;
  setText("statusUpdatedAt", `更新时间: ${currentRuntime.updatedAt}`);

  const level = Number(summary.level || localLevel.level || 1);
  const levelName = level >= 20 ? "宗师" : level >= 10 ? "老兵" : "新兵";
  const xp = Number(summary.xp || localLevel.xp || 0);
  const xpNext = Number(summary.xpNextTarget || localLevel.need || 320);
  const xpPercent = Number(summary.xpProgressPercent || localLevel.ratio || 0);

  setText("statusLevelLabel", `Lv.${level} ${levelName}`);
  setText("statusXpLabel", `当前经验 ${xp} / ${xpNext}`);
  const xpFill = document.getElementById("statusXpFill");
  if (xpFill) xpFill.style.width = `${Math.max(0, Math.min(100, xpPercent))}%`;

  const metrics = [
    { label: "模型路由", value: optionLabel(modelRoutes, currentRoleState.modelRoute), note: "当前主路线" },
    { label: "规则档位", value: optionLabel(tokenRules, currentRoleState.tokenRule), note: "调用节奏" },
    { label: "技能包", value: optionLabel(packageDefs, currentRoleState.skillPack), note: "默认基线" },
    { label: "Token消耗", value: `${Number(summary.tokensUsed || 0)}`, note: `使用时长 ${Number(summary.hoursPlayed || 0).toFixed(2)} 小时` },
    { label: "任务成功率", value: `${(Number(summary.successRate || 0) * 100).toFixed(1)}%`, note: `完成 ${Number(summary.tasksCompleted || 0)} / 成功 ${Number(summary.tasksSuccess || 0)}` },
    { label: "Skill使用率", value: `${Number(summary.skillUsageRate || 0).toFixed(1)}%`, note: `使用 ${Number(summary.usedSkillsCount || 0)} / 已装 ${Number(summary.installedSkillsCount || currentRoleState.installedSkills.length)}` },
    { label: "Token/成功任务比", value: `${Number(summary.tokensPerSuccess || 0).toFixed(2)}`, note: "越低越稳" },
    { label: "用户不满度", value: `${Number(summary.userDissatisfaction || 0).toFixed(1)}%`, note: "综合失败率与资源压力" },
  ];

  const metricTarget = document.getElementById("systemMetrics");
  if (metricTarget) {
    metricTarget.innerHTML = metrics
      .map(
        (item) => `
          <article class="metric-card">
            <span>${item.label}</span>
            <strong>${item.value}</strong>
            <small>${item.note}</small>
          </article>`,
      )
      .join("");
  }

  const readonly = [
    { title: "当前职业", value: roleProfiles[currentRole].title },
    { title: "模型配置", value: `${String(summary.mainModel || "未配置")} / ${String(summary.fallbackModel || "Qwen/Qwen3-8B")}` },
    { title: "技能状态", value: `${currentRoleState.installedSkills.length} 已装 · ${enabledSkillIds(currentRoleState).length} 启用` },
    { title: "装备状态", value: `${Object.values(currentRoleState.equipped).filter(Boolean).length}/${SLOT_ORDER.length} · 联动 ${computeActiveSynergies(currentRoleState).length}` },
    { title: "规则路由", value: `${optionLabel(tokenRules, currentRoleState.tokenRule)} · ${optionLabel(modelRoutes, currentRoleState.modelRoute)}` },
    { title: "办公室", value: readOfficeName(currentRole) },
  ];
  const readonlyTarget = document.getElementById("readonlyOverview");
  if (readonlyTarget) {
    readonlyTarget.innerHTML = readonly
      .map(
        (item) => `
          <article class="readonly-card compact">
            <span>${item.title}</span>
            <strong>${item.value}</strong>
          </article>`,
      )
      .join("");
  }
}

function setStatusDiagOutput(text) {
  const output = document.getElementById("statusDiagOutput");
  if (!output) return;
  output.textContent = text;
}

function setStatusDiagButtons(disabled) {
  document.querySelectorAll(".status-diag-btn").forEach((button) => {
    button.disabled = disabled;
  });
}

async function runStatusDiagnostic(cmd) {
  if (statusDiagBusy) return;
  statusDiagBusy = true;
  setStatusDiagButtons(true);
  setStatusDiagOutput(`执行中: openclaw ${cmd} ...`);
  try {
    const response = await fetch(DIAGNOSE_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ cmd }),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok || !payload?.ok) {
      throw new Error(payload?.msg || `HTTP ${response.status}`);
    }
    const exitCode = Number(payload.code ?? 0);
    const output = String(payload.output || "(无输出)");
    const ranAt = payload.ranAt ? new Date(payload.ranAt).toLocaleString() : new Date().toLocaleString();
    setStatusDiagOutput(`[openclaw ${cmd}] exit=${exitCode} @ ${ranAt}

${output}`);
  } catch (error) {
    setStatusDiagOutput(`执行失败: openclaw ${cmd}

${error.message}`);
  } finally {
    statusDiagBusy = false;
    setStatusDiagButtons(false);
  }
}

function renderTasksTab() {
  const workflow = [
    { step: "01", title: "确认任务边界", body: "明确目标、时限与输出格式。" },
    { step: "02", title: "装配当前构筑", body: "补齐技能与装备后再执行。" },
    { step: "03", title: "执行并回传进度", body: "关键节点同步进度与结果。" },
    { step: "04", title: "复盘并结算", body: "记录异常、建议与后续动作。" },
  ];
  const workflowTarget = document.getElementById("workflowBoard");
  if (workflowTarget) {
    workflowTarget.innerHTML = workflow
      .map(
        (item) => `
          <article class="task-card">
            <span>${item.step}</span>
            <strong>${item.title}</strong>
            <p>${item.body}</p>
          </article>`,
      )
      .join("");
  }

  const rewards = [
    { step: "XP", title: "经验奖励", body: `当前构筑预计经验 ${computeLevel(currentRoleState).xp}。` },
    { step: "FIT", title: "构筑适配", body: `已启用 ${enabledSkillIds(currentRoleState).length} 技能 / 已装备 ${Object.values(currentRoleState.equipped).filter(Boolean).length} 工具。` },
    { step: "RANK", title: "未来星级", body: "预留社区质量评分与排行入口。" },
  ];
  const rewardTarget = document.getElementById("rewardBoard");
  if (rewardTarget) {
    rewardTarget.innerHTML = rewards
      .map(
        (item) => `
          <article class="task-card">
            <span>${item.step}</span>
            <strong>${item.title}</strong>
            <p>${item.body}</p>
          </article>`,
      )
      .join("");
  }
}

function setActiveTab(tabId) {
  currentRoleState.activeTab = VALID_TABS.includes(tabId) ? tabId : "role";
  document.querySelectorAll(".tab-button").forEach((button) => {
    button.classList.toggle("active", button.dataset.tab === currentRoleState.activeTab);
  });
  document.querySelectorAll(".tab-panel").forEach((panel) => {
    panel.classList.toggle("active", panel.dataset.panel === currentRoleState.activeTab);
  });
  try {
    const url = new URL(window.location.href);
    url.searchParams.set("tab", currentRoleState.activeTab);
    window.history.replaceState({}, "", url.toString());
  } catch {
    // ignore
  }
}

function commitAndRender(rerenderEquipment = true) {
  persistCurrentRoleState();
  markCurrentTabDirty();
  renderAll();
  if (!rerenderEquipment) {
    renderSummaryStrip();
  }
}

function renderAll() {
  renderBanner();
  renderSummaryStrip();
  renderRoleTab();
  renderSkillsTab();
  renderEquipmentTab();
  renderStatusTab();
  renderTasksTab();
  setActiveTab(currentRoleState.activeTab);
}

async function refreshRuntime() {
  if (typeof document !== "undefined" && document.hidden) return;
  const projection = safeParseJson(window.localStorage.getItem(runtimeProjectionKey), null);
  if (projection?.runtime) {
    currentRuntime = normalizeRuntime(projection.runtime);
  }
  try {
    const response = await fetch(STATUS_SUMMARY_ENDPOINT, { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const payload = await response.json();
    if (payload?.runtime) {
      currentRuntime = normalizeRuntime(payload.runtime);
    }
    if (payload?.summary && typeof payload.summary === "object") {
      currentStatusSummary = payload.summary;
      if (payload.summary.identity && typeof payload.summary.identity === "object") {
        currentIdentity = writeIdentityProfile({ ...currentIdentity, ...payload.summary.identity });
      }
    }
  } catch {
    try {
      const fallback = await fetch(STATUS_ENDPOINT, { cache: "no-store" });
      if (fallback.ok) currentRuntime = normalizeRuntime(await fallback.json());
    } catch {
      // keep projection/runtime snapshot
    }
  }
  renderBanner();
  renderSummaryStrip();
  renderStatusTab();
}

function bindEvents() {
  document.querySelectorAll(".tab-button").forEach((button) => {
    button.addEventListener("click", () => {
      setActiveTab(button.dataset.tab);
      persistCurrentRoleState();
    });
  });

  document.querySelectorAll(".tab-save-btn").forEach((button) => {
    button.addEventListener("click", () => {
      const scope = String(button.dataset.scope || "all");
      applyRoleStateToBackend(scope, button);
    });
  });

  const identityMap = {
    identityAssistantNameInput: "assistantName",
    identityUserNameInput: "userName",
    identityRegionInput: "region",
    identityTimezoneInput: "timezone",
    identityGoalInput: "goal",
    identityPersonalityInput: "personality",
    identityWorkStyleInput: "workStyle",
  };
  Object.entries(identityMap).forEach(([id, key]) => {
    const el = document.getElementById(id);
    if (!el) return;
    el.addEventListener("input", () => {
      currentIdentity = writeIdentityProfile({ ...currentIdentity, [key]: el.value });
      setSaveStatus("role", "待保存");
    });
    el.addEventListener("change", () => {
      currentIdentity = writeIdentityProfile({ ...currentIdentity, [key]: el.value });
      setSaveStatus("role", "待保存");
    });
  });

  document.getElementById("statusRunDoctorBtn")?.addEventListener("click", () => runStatusDiagnostic("doctor"));
  document.getElementById("statusRunStatusBtn")?.addEventListener("click", () => runStatusDiagnostic("status"));
  document.getElementById("statusRunHealthBtn")?.addEventListener("click", () => runStatusDiagnostic("health"));

  document.getElementById("saveOfficeNameBtn")?.addEventListener("click", () => {
    const input = document.getElementById("officeNameInput");
    writeOfficeName(input?.value || defaultOfficeNameForRole(currentRole));
    renderBanner();
    renderSummaryStrip();
    renderStatusTab();
  });

  document.getElementById("resetOfficeNameBtn")?.addEventListener("click", () => {
    writeOfficeName(defaultOfficeNameForRole(currentRole));
    renderBanner();
    renderSummaryStrip();
    renderStatusTab();
    const input = document.getElementById("officeNameInput");
    if (input) input.value = readOfficeName(currentRole);
  });

  document.getElementById("confirmRoleChangeBtn")?.addEventListener("click", () => {
    if (previewRole === currentRole) return;
    pendingRoleChange = previewRole;
    openRoleConfirmModal();
  });

  document.getElementById("cancelRoleChangeBtn")?.addEventListener("click", () => {
    pendingRoleChange = null;
    closeRoleConfirmModal();
  });

  document.getElementById("applyRoleChangeBtn")?.addEventListener("click", () => {
    applyRoleChange();
  });

  document.getElementById("roleConfirmModal")?.addEventListener("click", (event) => {
    if (event.target.id === "roleConfirmModal") {
      pendingRoleChange = null;
      closeRoleConfirmModal();
    }
  });

  window.addEventListener("storage", (event) => {
    if (![stateKey, runtimeProjectionKey, OFFICE_PLAQUE_STORAGE_KEY, identityKey, "openclaw.persona.role"].includes(event.key)) return;
    currentRole = readRole();
    previewRole = currentRole;
    currentRoleState = hydrateRoleState(currentRole, loadRoleState(currentRole));
    selectedSkillId = currentRoleState.selectedSkillId;
    selectedToolId = currentRoleState.selectedToolId;
    currentIdentity = readIdentityProfile();
    refreshRuntime();
    renderAll();
  });
}

async function bootstrapCompactConfigure() {
  await hydrateDynamicCatalog();
  currentRole = readRole();
  previewRole = currentRole;
  window.localStorage.setItem("openclaw.persona.role", currentRole);
  currentRoleState = hydrateRoleState(currentRole, loadRoleState(currentRole));
  const requestedTab = readRequestedTab();
  if (requestedTab) currentRoleState.activeTab = requestedTab;
  selectedSkillId = currentRoleState.selectedSkillId;
  selectedToolId = currentRoleState.selectedToolId;
  currentIdentity = readIdentityProfile();
  if (!window.localStorage.getItem(OFFICE_PLAQUE_STORAGE_KEY)) {
    writeOfficeName(defaultOfficeNameForRole(currentRole));
  }
  bindEvents();
  persistCurrentRoleState();
  Object.keys(TAB_SAVE_STATUS_IDS).forEach((scope) => setSaveStatus(scope, "待保存"));
  renderAll();
  refreshRuntime();
  window.setInterval(() => {
    if (!document.hidden) refreshRuntime();
  }, 8000);
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) refreshRuntime();
  });
}

bootstrapCompactConfigure().catch(() => {});
