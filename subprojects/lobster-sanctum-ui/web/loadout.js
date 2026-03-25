const defaultRole = "druid";

const roleProfiles = {
  druid: {
    className: "通用总管",
    title: "万金油 · 德鲁伊",
    desc: "负责综合协同、日程编排、写作整理、搜索归纳和任务跟进，适合把龙虾作为长期小助理使用。",
    image: "./assets/role-druid.png",
    portraitPosition: "center 18%",
    specialty: "综合协同",
    primaryModel: "Claude / GPT",
    tempo: "稳定推进",
    tree: [
      { name: "任务调度", tier: "核心", desc: "把杂乱需求拆成可执行清单并持续跟进。" },
      { name: "资料整理", tier: "通用", desc: "将搜索、邮件、文档和表格统一归档。" },
      { name: "主动巡航", tier: "增强", desc: "定时回顾进度、发现异常并主动汇报。" },
    ],
    gear: [
      { slot: "主手", name: "proactive-agent", note: "主动推进与跟进" },
      { slot: "副手", name: "openclaw-cron-setup", note: "周期巡检与代办唤醒" },
      { slot: "饰品", name: "agentmail", note: "邮件起草与往来处理" },
      { slot: "卷轴", name: "docx / xlsx", note: "文档与表格输出" },
    ],
    workflow: ["先收集目标与约束", "自动拆分任务与时序", "调用搜索与文档技能整理结果", "完成后输出复盘与下一步建议"],
    toggles: ["主动汇报", "文档总结", "定时巡检", "邮件输出"],
    tasks: ["日程制定", "邮件写作", "综合搜索", "事务统筹"],
  },
  assassin: {
    className: "投资分析",
    title: "分析员 · 刺客",
    desc: "聚焦市场、财务、公司与行业线索挖掘，强调事实、估值、对比与风险收益结构。",
    image: "./assets/role-assassin.png",
    portraitPosition: "center 20%",
    specialty: "深度分析",
    primaryModel: "Claude",
    tempo: "冷静拆解",
    tree: [
      { name: "机会扫描", tier: "核心", desc: "批量抓取公司、行业、新闻和财报信号。" },
      { name: "估值解剖", tier: "核心", desc: "做横向比较和盈利假设分层。" },
      { name: "风险捕手", tier: "增强", desc: "标注关键风险点和不确定性。" },
    ],
    gear: [
      { slot: "主手", name: "akshare-stock", note: "证券数据抓取" },
      { slot: "副手", name: "stock-monitor-skill", note: "盯盘与跟踪" },
      { slot: "饰品", name: "multi-search-engine", note: "多源交叉搜索" },
      { slot: "卷轴", name: "xlsx", note: "表格建模与比较" },
    ],
    workflow: ["拉取市场与财报数据", "构建对比视角", "抽取风险收益与催化剂", "输出结论与观察清单"],
    toggles: ["新闻雷达", "多引擎搜索", "风险标注", "表格输出"],
    tasks: ["投资分析", "行业研究", "公司调研", "估值比较"],
  },
  mage: {
    className: "研究学习",
    title: "研究者 · 大法师",
    desc: "以证据链、论文、读书笔记、研究方案和知识整理为核心，适合长期学习与学术产出。",
    image: "./assets/role-mage.png",
    portraitPosition: "center 16%",
    specialty: "知识归纳",
    primaryModel: "Claude / Gemini",
    tempo: "沉浸研究",
    tree: [
      { name: "文献整理", tier: "核心", desc: "归纳论文、材料与引用关系。" },
      { name: "结构总结", tier: "核心", desc: "把长文转为大纲、卡片和综述。" },
      { name: "论证回路", tier: "增强", desc: "检查证据链和反证路径。" },
    ],
    gear: [
      { slot: "主手", name: "pdf", note: "论文与 PDF 解析" },
      { slot: "副手", name: "docx / pptx", note: "研究输出与演示" },
      { slot: "饰品", name: "tavily-search", note: "资料外部检索" },
      { slot: "卷轴", name: "summarize", note: "长文压缩" },
    ],
    workflow: ["确定研究问题", "检索并清洗材料", "做结构化摘要", "输出综述、提纲和下一轮问题"],
    toggles: ["多轮摘要", "PDF 解析", "证据对照", "PPT 输出"],
    tasks: ["论文阅读", "学习笔记", "研究计划", "知识库整理"],
  },
  summoner: {
    className: "组织管理",
    title: "管理者 · 召唤师",
    desc: "用于招聘、组织、流程、例会和项目推进，强调多人协同与系统性管理。",
    image: "./assets/role-summoner.png",
    portraitPosition: "center 18%",
    specialty: "组织编排",
    primaryModel: "Claude",
    tempo: "稳态指挥",
    tree: [
      { name: "项目拆解", tier: "核心", desc: "把目标拆成人、事、时间和节点。" },
      { name: "会议纪要", tier: "通用", desc: "自动归纳行动项和责任人。" },
      { name: "组织脉络", tier: "增强", desc: "梳理流程、岗位与协作边界。" },
    ],
    gear: [
      { slot: "主手", name: "docx", note: "制度、JD、会议文档" },
      { slot: "副手", name: "xlsx", note: "人力与项目表格" },
      { slot: "饰品", name: "agentmail", note: "沟通通知" },
      { slot: "卷轴", name: "github", note: "项目协同" },
    ],
    workflow: ["确认目标与角色", "拆解资源和时间线", "跟踪执行与异常", "输出纪要、规则和复盘"],
    toggles: ["主动汇报", "纪要模板", "任务分派", "流程复盘"],
    tasks: ["招聘管理", "团队协作", "流程治理", "项目推进"],
  },
  warrior: {
    className: "工程开发",
    title: "技术员 · 战士",
    desc: "偏工程交付，负责代码实现、测试排障、脚本自动化和稳定性建设。",
    image: "./assets/role-warrior.png",
    portraitPosition: "center 18%",
    specialty: "工程交付",
    primaryModel: "Codex",
    tempo: "快速迭代",
    tree: [
      { name: "代码铸造", tier: "核心", desc: "从需求直接落代码、补测试、改接口。" },
      { name: "问题歼灭", tier: "核心", desc: "定位异常、追栈、修复并验证。" },
      { name: "自动流水线", tier: "增强", desc: "把重复工作交给脚本和工具链。" },
    ],
    gear: [
      { slot: "主手", name: "shell", note: "脚本与系统操作" },
      { slot: "副手", name: "github", note: "版本与协作" },
      { slot: "饰品", name: "chrome-devtools-mcp", note: "前端调试" },
      { slot: "卷轴", name: "agent-browser", note: "浏览器自动化" },
    ],
    workflow: ["读取现状与约束", "写最小可验证修改", "跑测试与浏览器验证", "输出结果与后续风险"],
    toggles: ["自动验证", "浏览器调试", "日志巡检", "命令行执行"],
    tasks: ["开发交付", "问题排障", "前端调试", "自动化脚本"],
  },
  paladin: {
    className: "增长运营",
    title: "营销者 · 圣骑士",
    desc: "聚焦内容增长、渠道运营、SEO、投放复盘和客户沟通。",
    image: "./assets/role-paladin.png",
    portraitPosition: "center 18%",
    specialty: "增长推进",
    primaryModel: "Claude / Gemini",
    tempo: "高频推进",
    tree: [
      { name: "内容引擎", tier: "核心", desc: "规划选题、渠道分发和再利用。" },
      { name: "转化追踪", tier: "核心", desc: "围绕漏斗和投放做复盘。" },
      { name: "关系维护", tier: "增强", desc: "邮件、私域和客户触点管理。" },
    ],
    gear: [
      { slot: "主手", name: "web-search", note: "竞品与热点追踪" },
      { slot: "副手", name: "agentmail", note: "客户沟通" },
      { slot: "饰品", name: "frontend-design", note: "活动页面与素材" },
      { slot: "卷轴", name: "xlsx", note: "漏斗数据分析" },
    ],
    workflow: ["确定目标用户和渠道", "规划内容与分发", "监控转化和反馈", "复盘并迭代素材和话术"],
    toggles: ["搜索监控", "内容复盘", "邮件触达", "素材生成"],
    tasks: ["内容运营", "SEO 优化", "广告复盘", "客户沟通"],
  },
  archer: {
    className: "设计创意",
    title: "设计师 · 弓箭手",
    desc: "覆盖 UI、前端、图像、海报、视频分镜和创意表达，强调视觉呈现与质感。",
    image: "./assets/role-archer.png",
    portraitPosition: "center 18%",
    specialty: "视觉创作",
    primaryModel: "Gemini / Nano Banana",
    tempo: "灵感爆发",
    tree: [
      { name: "界面塑形", tier: "核心", desc: "做页面、交互和版式方案。" },
      { name: "图像召唤", tier: "核心", desc: "生成角色、KV、海报和概念图。" },
      { name: "动态叙事", tier: "增强", desc: "扩展到分镜、短视频和动效。" },
    ],
    gear: [
      { slot: "主手", name: "frontend-design", note: "页面与 UI 设计" },
      { slot: "副手", name: "gemini-image-service", note: "图像理解与生成" },
      { slot: "饰品", name: "nano-banana-service", note: "概念图与人物图" },
      { slot: "卷轴", name: "grok-imagine-1.0-video", note: "视频和动态内容" },
    ],
    workflow: ["先确定风格与素材方向", "产出界面与视觉方案", "生成图像与补图", "导出分镜、文案和最终物料"],
    toggles: ["图像生成", "界面草图", "视频分镜", "设计摘要"],
    tasks: ["UI 设计", "海报 KV", "视频概念", "品牌素材"],
  },
};

function readRoleFromQuery() {
  const params = new URLSearchParams(window.location.search);
  return params.get("role") || window.localStorage.getItem("openclaw.persona.role") || defaultRole;
}

function fillList(target, items, formatter) {
  target.innerHTML = "";
  items.forEach((item) => {
    const li = document.createElement("li");
    li.innerHTML = formatter(item);
    target.appendChild(li);
  });
}

function renderLoadout(role) {
  const profile = roleProfiles[role] || roleProfiles[defaultRole];
  const loadoutPortrait = document.getElementById("loadoutPortrait");
  loadoutPortrait.src = profile.image;
  loadoutPortrait.alt = `${profile.title}立绘`;
  loadoutPortrait.style.objectPosition = profile.portraitPosition || "center 18%";
  document.getElementById("loadoutClass").textContent = profile.className;
  document.getElementById("loadoutTitle").textContent = profile.title;
  document.getElementById("loadoutDesc").textContent = profile.desc;
  document.getElementById("loadoutSpecialty").textContent = profile.specialty;
  document.getElementById("loadoutPrimaryModel").textContent = profile.primaryModel;
  document.getElementById("loadoutTempo").textContent = profile.tempo;

  fillList(
    document.getElementById("skillTree"),
    profile.tree,
    (item) => `
      <article class="skill-node">
        <p class="skill-tier">${item.tier}</p>
        <h4>${item.name}</h4>
        <p>${item.desc}</p>
      </article>
    `,
  );

  fillList(
    document.getElementById("gearGrid"),
    profile.gear,
    (item) => `
      <article class="gear-card">
        <p class="gear-slot">${item.slot}</p>
        <h4>${item.name}</h4>
        <p>${item.note}</p>
      </article>
    `,
  );

  fillList(document.getElementById("workflowList"), profile.workflow, (item) => item);
  fillList(document.getElementById("toggleList"), profile.toggles, (item) => item);
  fillList(document.getElementById("taskOverview"), profile.tasks, (item) => item);
}

const currentRole = readRoleFromQuery();

document.getElementById("proceedStageBtn").addEventListener("click", () => {
  window.localStorage.setItem("openclaw.persona.role", currentRole);
  window.location.href = `./configure.html?role=${encodeURIComponent(currentRole)}`;
});

renderLoadout(currentRole);
