const roleProfiles = {
  druid: {
    className: "通用总管",
    title: "万金油 · 德鲁伊",
    desc: "全能型人格，适合绝大多数用户，擅长把碎片需求整合为可执行计划，并持续跟进任务闭环。",
    intro:
      "负责综合协同、日程编排、写作整理、搜索归纳和任务跟进。适合把龙虾作为长期小助理使用的用户。",
    image: "./assets/role-druid.png",
    portraitPosition: "center 18%",
    skills: ["proactive-agent", "openclaw-cron-setup", "reflection", "find-skills", "shell", "web-search", "summarize", "docx", "xlsx", "agentmail"],
    models: [
      { name: "Claude", note: "通用协作、长文本整理、复杂任务跟进更稳。" },
      { name: "GPT", note: "日常问答、执行类任务和综合助理场景兼容性高。" },
    ],
    tasks: ["制定日程与提醒", "邮件与文稿起草", "日常搜索与资料整理", "多任务统筹与复盘"],
  },
  assassin: {
    className: "投资分析",
    title: "分析员 · 刺客",
    desc: "高敏分析人格，聚焦数据、信息差与机会识别，强调事实、估值框架和风险比较。",
    intro:
      "偏向券商分析师工作流，擅长追踪市场、拆解财务、寻找线索和比较风险收益，适合投资与行业判断。",
    image: "./assets/role-assassin.png",
    portraitPosition: "center 20%",
    skills: ["akshare-stock", "stock-monitor-skill", "multi-search-engine", "web-search", "tavily-search", "news-radar", "summarize", "url-to-markdown", "xlsx"],
    models: [
      { name: "Claude", note: "投资分析、估值拆解、长链条推理更适配。" },
      { name: "GPT", note: "快速比较、表格结构化整理和研究摘要也适合。" },
    ],
    tasks: ["投资机会挖掘", "行业与公司研报", "估值比较与风险提示", "新闻与财报跟踪"],
  },
  mage: {
    className: "研究学习",
    title: "研究者 · 大法师",
    desc: "知识驱动人格，善于搭研究框架、整理证据链、做论文阅读和结构化学习输出。",
    intro:
      "偏向学术研究和知识管理，适合论文、读书、笔记、研究计划、学习路线和证据归档类任务。",
    image: "./assets/role-mage.png",
    portraitPosition: "center 16%",
    skills: ["brainstorming", "summarize", "web-search", "tavily-search", "url-to-markdown", "docx", "pdf", "nano-pdf", "pptx", "xlsx"],
    models: [
      { name: "Claude", note: "长文阅读、论文总结、结构化研究输出很强。" },
      { name: "Gemini", note: "多模态材料理解、图表和长上下文资料处理适合。" },
    ],
    tasks: ["论文阅读与综述", "读书笔记与知识卡片", "研究方案设计", "材料证据链整理"],
  },
  summoner: {
    className: "组织管理",
    title: "管理者 · 召唤师",
    desc: "组织协同人格，用于团队流程、任务拆解、招聘协作、项目推进和管理复盘。",
    intro:
      "偏企业管理场景，适合招聘、人力、组织架构、流程规范、例会纪要、团队目标拆解等任务。",
    image: "./assets/role-summoner.png",
    portraitPosition: "center 18%",
    skills: ["proactive-agent", "openclaw-cron-setup", "docx", "xlsx", "pptx", "agentmail", "github", "reflection"],
    models: [
      { name: "Claude", note: "管理文档、组织方案、流程设计和长文本沟通更适合。" },
      { name: "GPT", note: "项目推进、任务拆解、轻量协调类交互效率高。" },
    ],
    tasks: ["团队任务编排", "招聘与人力协同", "流程治理与规范", "项目推进与复盘"],
  },
  warrior: {
    className: "工程开发",
    title: "技术员 · 战士",
    desc: "工程执行人格，专注代码实现、测试排障、自动化、DevOps 和稳定性建设。",
    intro:
      "偏全栈铁匠，负责写代码、修问题、补测试、搭脚本、排查服务异常和交付上线，适合技术场景。",
    image: "./assets/role-warrior.png",
    portraitPosition: "center 18%",
    skills: ["shell", "github", "mcp-builder", "chrome-devtools-mcp", "agent-browser", "model-usage", "web-search", "minimax-understand-image", "reflection"],
    models: [
      { name: "Codex", note: "程序开发、代码修改、测试和排障最适配。" },
      { name: "Claude", note: "复杂架构分析、代码审查和文档说明可以搭配使用。" },
    ],
    tasks: ["代码开发与重构", "测试与排障", "自动化脚本", "服务稳定性与工程交付"],
  },
  paladin: {
    className: "增长运营",
    title: "营销者 · 圣骑士",
    desc: "增长运营人格，围绕内容分发、渠道运营、SEO、投放转化和客户关系维护。",
    intro:
      "偏市场与运营团队，适合内容策略、广告投放、SEO、客户沟通、私域增长和分发复盘等任务。",
    image: "./assets/role-paladin.png",
    portraitPosition: "center 18%",
    skills: ["web-search", "tavily-search", "news-radar", "summarize", "url-to-markdown", "docx", "xlsx", "agentmail", "frontend-design", "web-design"],
    models: [
      { name: "Claude", note: "营销策略、内容规划、增长分析与客户沟通更适配。" },
      { name: "Gemini", note: "图文内容、渠道素材和多模态运营输出可以辅助。" },
    ],
    tasks: ["内容增长与渠道运营", "SEO 与投放策略", "客户运营与邮件沟通", "增长复盘"],
  },
  archer: {
    className: "设计创意",
    title: "设计师 · 弓箭手",
    desc: "创意视觉人格，覆盖前端、UI、平面、美术、工业设计和自媒体视觉表达。",
    intro:
      "负责视觉呈现与创意落地，适合做界面设计、人物设定、海报、图像生成、短视频分镜和设计方案表达。",
    image: "./assets/role-archer.png",
    portraitPosition: "center 18%",
    skills: ["frontend-design", "web-design", "gemini-image-service", "nano-banana-service", "grok-imagine-1.0-video", "pptx", "docx", "summarize"],
    models: [
      { name: "Gemini", note: "界面草图、多模态设计理解和图像相关任务很适合。" },
      { name: "Nano Banana", note: "人物、KV、概念图和风格图生成更适配。" },
      { name: "C/Dance", note: "动效、视频和视觉表现类任务可作为补充。" },
    ],
    tasks: ["前端与 UI 设计", "海报与图像生成", "视频分镜与视觉概念", "品牌与自媒体素材"],
  },
};

const defaultRole = "druid";
const hotspots = Array.from(document.querySelectorAll(".map-node"));
const groupPortrait = document.getElementById("groupPortrait");
const portraitCard = document.getElementById("portraitCard");
const rolePortrait = document.getElementById("rolePortrait");
const roleClass = document.getElementById("roleClass");
const roleTitle = document.getElementById("roleTitle");
const roleDesc = document.getElementById("roleDesc");
const roleIntro = document.getElementById("roleIntro");
const roleSkills = document.getElementById("roleSkills");
const roleModels = document.getElementById("roleModels");
const roleTasks = document.getElementById("roleTasks");
const confirmBtn = document.getElementById("confirmBtn");
const resetBtn = document.getElementById("resetBtn");
const nextStepBtn = document.getElementById("nextStepBtn");

let currentRole = defaultRole;

function persistRole(role) {
  window.localStorage.setItem("openclaw.persona.role", role);
}

function goToNextStage() {
  persistRole(currentRole);
  window.location.href = `./loadout.html?role=${encodeURIComponent(currentRole)}`;
}

function fillList(target, items, formatter) {
  target.innerHTML = "";
  items.forEach((item) => {
    const li = document.createElement("li");
    li.innerHTML = formatter(item);
    target.appendChild(li);
  });
}

function renderRole(role) {
  const profile = roleProfiles[role];
  if (!profile) {
    return;
  }

  currentRole = role;
  persistRole(role);
  roleClass.textContent = profile.className;
  roleTitle.textContent = profile.title;
  roleDesc.textContent = profile.desc;
  roleIntro.textContent = profile.intro;
  rolePortrait.src = profile.image;
  rolePortrait.alt = `${profile.title}完整立绘`;
  rolePortrait.style.objectPosition = profile.portraitPosition || "center 18%";

  fillList(roleSkills, profile.skills, (item) => item);
  fillList(roleModels, profile.models, (item) => `<span class="model-label">${item.name}</span>${item.note}`);
  fillList(roleTasks, profile.tasks, (item) => item);

  hotspots.forEach((hotspot) => {
    hotspot.classList.toggle("active", hotspot.dataset.role === role);
  });
}

function resetPortraitCard() {
  portraitCard.style.transform = "rotateX(0deg) rotateY(0deg)";
}

hotspots.forEach((hotspot) => {
  hotspot.addEventListener("click", () => {
    renderRole(hotspot.dataset.role);
  });
});

groupPortrait.parentElement.addEventListener("mousemove", (event) => {
  const rect = groupPortrait.parentElement.getBoundingClientRect();
  const x = (event.clientX - rect.left) / rect.width - 0.5;
  groupPortrait.style.transform = `translateX(${x * 8}px) scale(1.01)`;
});

groupPortrait.parentElement.addEventListener("mouseleave", () => {
  groupPortrait.style.transform = "translateX(0) scale(1)";
});

portraitCard.addEventListener("mousemove", (event) => {
  const rect = portraitCard.getBoundingClientRect();
  const x = (event.clientX - rect.left) / rect.width - 0.5;
  const y = (event.clientY - rect.top) / rect.height - 0.5;
  portraitCard.style.transform = `rotateX(${y * -10}deg) rotateY(${x * 12}deg)`;
});

portraitCard.addEventListener("mouseleave", resetPortraitCard);

confirmBtn.addEventListener("click", () => {
  goToNextStage();
});

resetBtn.addEventListener("click", () => {
  renderRole(defaultRole);
  resetPortraitCard();
});

nextStepBtn.addEventListener("click", () => {
  goToNextStage();
});

renderRole(defaultRole);
