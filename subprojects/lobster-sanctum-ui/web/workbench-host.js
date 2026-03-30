(function () {
  const params = new URLSearchParams(window.location.search);
  const embedded = params.get("embedded") === "1";
  const hideChrome = params.get("chrome") === "0";
  const theme = params.get("theme") || "";
  const source = params.get("source") || "";
  const mode = params.get("mode") || "";
  const role = params.get("role") || window.localStorage.getItem("openclaw.persona.role") || "druid";

  if (!embedded) {
    return;
  }

  const stationMeta = {
    role: {
      title: "职业控制",
      kicker: "办公室 / 职业与规则",
      desc: "切换职业、办公室命名、规则档位、模型路由和安全开关。",
      stats: ["7 个职业人格", "办公室命名", "规则与安全"],
      cta: "调整职业",
      href: "./configure.html?tab=role",
    },
    skills: {
      title: "技能工坊",
      kicker: "书桌 / 技能管理",
      desc: "只保留已安装技能、备选技能库和默认技能包三个核心区块。",
      stats: ["启用 / 停用", "技能库补装", "默认包切换"],
      cta: "整理技能",
      href: "./configure.html?tab=skills",
    },
    equipment: {
      title: "装备库",
      kicker: "铁匠台 / 装备与物品",
      desc: "保留人物装备栏和物品格，把模型、MCP、API 和工具直接装配到角色身上。",
      stats: ["12 个装备槽位", "统一物品栏", "套装说明收束"],
      cta: "整理装备",
      href: "./configure.html?tab=equipment",
    },
    status: {
      title: "状态成长",
      kicker: "观察站 / 只读状态",
      desc: "只读查看运行状态、系统参数、成长经验和当前构筑摘要。",
      stats: ["运行状态", "系统参数", "经验成长"],
      cta: "查看状态",
      href: "./configure.html?tab=status",
    },
    tasks: {
      title: "任务流程",
      kicker: "任务墙 / 工作流",
      desc: "先保留标准工作流、奖励框架和未来社区星级的占位结构。",
      stats: ["标准流程", "奖励框架", "未来占位"],
      cta: "查看任务",
      href: "./configure.html?tab=tasks",
    },
  };

  const roleNames = {
    druid: "万金油 · 德鲁伊",
    assassin: "分析员 · 刺客",
    mage: "研究者 · 大法师",
    summoner: "管理者 · 召唤师",
    warrior: "技术员 · 战士",
    paladin: "营销者 · 圣骑士",
    archer: "设计师 · 弓箭手",
  };
  const VALID_STATIONS = ["role", "skills", "equipment", "status", "tasks"];

  function navigateToStation(targetMode) {
    const meta = stationMeta[targetMode] || stationMeta.role;
    const url = new URL(meta.href, window.location.href);
    url.searchParams.set("embedded", "1");
    url.searchParams.set("theme", theme || "pixel-house");
    url.searchParams.set("source", "star-office");
    url.searchParams.set("mode", targetMode);
    url.searchParams.set("role", role);
    window.location.href = url.toString();
  }

  function resolveCurrentStation() {
    if (document.body.classList.contains("config-body")) {
      const requestedTab = params.get("tab");
      if (VALID_STATIONS.includes(requestedTab || "")) {
        return requestedTab;
      }
      if (VALID_STATIONS.includes(mode)) {
        return mode;
      }
      return "role";
    }
    if (document.body.classList.contains("loadout-body")) {
      return "skills";
    }
    return "role";
  }

  function applyEmbeddedClasses() {
    document.body.classList.add("workbench-embedded");
    if (theme) {
      document.body.dataset.theme = theme;
    }
    if (mode) {
      document.body.dataset.mode = mode;
    }
    if (source) {
      document.body.dataset.source = source;
    }
    document.body.dataset.role = role;
  }

  function setText(id, text) {
    const el = document.getElementById(id);
    if (el) {
      el.textContent = text;
    }
  }

  function tuneRolePage() {
    setText("confirmBtn", "切换为该职业");
    setText("resetBtn", "恢复默认职业");
    const cue = document.getElementById("nextStepBtn");
    if (cue) {
      cue.querySelector(".next-step-label")?.replaceChildren("下一步");
      cue.querySelector(".next-step-text")?.replaceChildren("前往技能树");
    }
  }

  function tuneLoadoutPage() {
    setText("proceedStageBtn", "进入指挥工坊");
  }

  function pruneForWorldConsole() {
    if (source !== "world-console") {
      return;
    }

    document.body.classList.add("world-console-embedded");

    if (document.body.classList.contains("config-body")) {
      document.querySelector(".config-banner")?.remove();
      document.querySelector(".tab-bar")?.remove();
      return;
    }

    if (document.body.classList.contains("loadout-body")) {
      document.querySelector(".loadout-banner")?.remove();
      return;
    }

    document.querySelector(".hero-stage")?.remove();
    document.querySelector(".next-step-cue")?.remove();
  }

  function tuneConfigurePage() {
    const modeName = resolveCurrentStation();
    const title = document.querySelector(".config-banner h1");
    const subtitle = document.querySelector(".config-banner .subtitle");
    const mapping = {
      role: {
        title: "职业控制",
        subtitle: "切换职业、办公室命名、规则档位、模型路由和安全开关。",
      },
      equipment: {
        title: "装备配置",
        subtitle: "整理人物装备栏、物品格和当前套装说明。",
      },
      status: {
        title: "状态成长",
        subtitle: "只读查看运行状态、系统参数和成长经验。",
      },
      tasks: {
        title: "任务流程",
        subtitle: "保留标准工作流、奖励框架和未来社区星级占位。",
      },
      skills: {
        title: "技能配置",
        subtitle: "只保留已安装技能、备选技能库和默认技能包。",
      },
    };
    const meta = mapping[modeName] || mapping.skills;
    if (title) {
      title.textContent = meta.title;
    }
    if (subtitle) {
      subtitle.textContent = meta.subtitle;
    }
    const runtimeBtn = document.getElementById("launchRuntimeBtn");
    if (runtimeBtn) {
      runtimeBtn.remove();
    }
  }

  function buildShell() {
    const currentStation = resolveCurrentStation();
    const meta = stationMeta[currentStation] || stationMeta.role;
    const shell = document.createElement("section");
    shell.className = "workbench-shell";
    shell.innerHTML = `
      <div class="workbench-shell__head">
        <div class="workbench-shell__copy">
          <p class="workbench-shell__kicker">${meta.kicker}</p>
          <h1 class="workbench-shell__title">${meta.title}</h1>
          <p class="workbench-shell__desc">${meta.desc}</p>
        </div>
        <div class="workbench-shell__identity">
          <span class="workbench-shell__identity-label">当前职业</span>
          <strong class="workbench-shell__identity-value">${roleNames[role] || role}</strong>
        </div>
      </div>
      <div class="workbench-shell__nav">
        <button type="button" data-station="role">职业</button>
        <button type="button" data-station="skills">技能</button>
        <button type="button" data-station="equipment">装备物品</button>
        <button type="button" data-station="status">状态成长</button>
        <button type="button" data-station="tasks">任务流程</button>
      </div>
      <div class="workbench-shell__stats">
        ${meta.stats
          .map(
            (item, index) => `
              <article class="workbench-shell__stat">
                <span>ST-${index + 1}</span>
                <strong>${item}</strong>
              </article>`,
          )
          .join("")}
      </div>
    `;
    document.body.prepend(shell);
    shell.querySelectorAll("[data-station]").forEach((button) => {
      const station = button.dataset.station;
      button.classList.toggle("active", station === currentStation);
      button.addEventListener("click", () => navigateToStation(station));
    });
  }

  window.addEventListener("DOMContentLoaded", () => {
    applyEmbeddedClasses();
    if (!hideChrome && source !== "world-console") {
      buildShell();
    }
    pruneForWorldConsole();
    if (document.body.classList.contains("loadout-body")) {
      tuneLoadoutPage();
      return;
    }
    if (document.body.classList.contains("config-body")) {
      tuneConfigurePage();
      return;
    }
    tuneRolePage();
  });
})();
