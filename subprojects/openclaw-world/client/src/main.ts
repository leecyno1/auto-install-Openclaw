import "./styles.css";

import type {
  BuildState,
  EquipmentItem,
  EquipmentSlotId,
  HomeStationId,
  RoleId,
  RoleProfile,
  RuntimeState,
  SkillCard,
  TaskPlan,
  WorldState,
} from "../../shared/world-model.js";
import { EQUIPMENT_CATALOG, HOME_STATIONS } from "../../shared/world-model.js";
import { api, type BuildResponse } from "./api.js";

type CatalogState = BuildResponse["skills"] & BuildResponse["equipment"];
type FlashTone = "info" | "success" | "warning";

const SLOT_ORDER: EquipmentSlotId[] = [
  "head",
  "amulet",
  "chest",
  "mainhand",
  "offhand",
  "belt",
  "boots",
];

const app = document.getElementById("app");

if (!app) {
  throw new Error("missing app root");
}

let build!: BuildState;
let runtime!: RuntimeState;
let world!: WorldState;
let roles: RoleProfile[] = [];
let tasks: TaskPlan[] = [];
let catalog: CatalogState = {
  installed: [],
  reserve: [],
  equipped: [],
  inventory: [],
};
let taskDraft = "";
let inspectedSlot: EquipmentSlotId = "chest";
let flashMessage = "正在连接 world gateway...";
let flashTone: FlashTone = "info";

app.innerHTML = `
  <div class="shell">
    <header class="topbar">
      <div class="topbar__title">
        <span class="eyebrow">OPENCLAW WORLD EXPERIMENT</span>
        <h1>Home Base Runtime</h1>
      </div>
      <div class="topbar__meta" id="topMeta"></div>
    </header>
    <main class="layout">
      <section class="stage-column">
        <section class="world-card">
          <div class="world-card__toolbar">
            <div class="world-card__tabs">
              <button class="tab-button" data-scene="home-base">Home Base</button>
              <button class="tab-button" data-scene="shared-world">Shared World</button>
            </div>
            <div class="world-card__actions">
              <button class="ghost-button" id="saveDraftButton">保存草稿</button>
              <button class="action-button action-button--gold" id="applyBuildButton">应用到 OpenClaw</button>
            </div>
          </div>
          <div class="world-card__canvas" id="worldCanvas"></div>
          <div class="world-card__statusline">
            <div>
              <strong id="stationLabel">基地控制台</strong>
              <span class="muted" id="stationHint">点击房间内对象切换控制面板。</span>
            </div>
            <span class="signal signal--info" id="flashBanner">正在加载...</span>
          </div>
        </section>
        <section class="task-dock" id="taskDock"></section>
      </section>
      <aside class="sidebar">
        <section class="summary-card" id="summaryCard"></section>
        <nav class="station-nav" id="stationNav"></nav>
        <section class="panel-card">
          <div class="panel-card__header">
            <strong id="panelTitle">基地控制台</strong>
            <span class="muted" id="panelHint">读取中...</span>
          </div>
          <div class="panel-card__body" id="panelBody"></div>
        </section>
      </aside>
    </main>
  </div>
`;

const worldCanvas = document.getElementById("worldCanvas") as HTMLElement;
const topMeta = document.getElementById("topMeta") as HTMLElement;
const summaryCard = document.getElementById("summaryCard") as HTMLElement;
const stationNav = document.getElementById("stationNav") as HTMLElement;
const panelTitle = document.getElementById("panelTitle") as HTMLElement;
const panelHint = document.getElementById("panelHint") as HTMLElement;
const panelBody = document.getElementById("panelBody") as HTMLElement;
const taskDock = document.getElementById("taskDock") as HTMLElement;
const stationLabel = document.getElementById("stationLabel") as HTMLElement;
const stationHint = document.getElementById("stationHint") as HTMLElement;
const flashBanner = document.getElementById("flashBanner") as HTMLElement;

let renderer:
  | {
      setBuild: (value: BuildState) => void;
      setRuntime: (value: RuntimeState) => void;
      setWorld: (value: WorldState) => void;
    }
  | undefined;

function setFlash(message: string, tone: FlashTone = "info") {
  flashMessage = message;
  flashTone = tone;
  renderFlash();
}

function renderFlash() {
  flashBanner.textContent = flashMessage;
  flashBanner.className = `signal signal--${flashTone}`;
}

function findRole(roleId: RoleId) {
  return roles.find((role) => role.id === roleId) || roles[0];
}

function stationInfo(stationId: HomeStationId) {
  return HOME_STATIONS[stationId];
}

function allEquipment() {
  return [...catalog.equipped, ...catalog.inventory].sort((a, b) => a.name.localeCompare(b.name));
}

function equipmentForSlot(slot: EquipmentSlotId): EquipmentItem[] {
  return allEquipment().filter((item) => item.slot === slot);
}

function draftInventoryItems() {
  const equippedIds = new Set(Object.values(build.equipment.slots).filter(Boolean));
  return allEquipment().filter((item) => !equippedIds.has(item.id));
}

function refreshInventoryFromSlots() {
  const equippedIds = new Set(Object.values(build.equipment.slots).filter(Boolean));
  build.equipment.inventory = EQUIPMENT_CATALOG.filter((item) => !equippedIds.has(item.id)).map(
    (item) => item.id,
  );
}

function rolePreset(roleId: RoleId) {
  const role = findRole(roleId);
  if (!role) return;
  build.roleId = roleId;
  build.identity.goal = role.description;
  build.routing.modelRoute = role.recommendedModelRoute;
  build.routing.tokenRule = roleId === "druid" ? "low" : "medium";
  build.routing.skillPack = roleId === "druid" ? "low" : "medium";
  build.routing.advancedModel = roleId === "warrior" ? "gpt-5.4" : "claude-main";
  build.skills.installed = [...role.starterSkills];
  build.skills.disabled = [];
  build.equipment.slots = {
    chest: role.starterEquipment.chest || "minimax-2-7",
    ...role.starterEquipment,
  };
  refreshInventoryFromSlots();
}

function selectedEquipment(slot: EquipmentSlotId) {
  const equipmentId = build.equipment.slots[slot];
  return allEquipment().find((item) => item.id === equipmentId) || null;
}

function roleButtonMarkup(role: RoleProfile) {
  const active = role.id === build.roleId ? "is-active" : "";
  return `
    <button class="role-card ${active}" data-role-id="${role.id}">
      <div class="role-card__top">
        <strong>${role.emoji} ${role.title}</strong>
        <small>${role.className}</small>
      </div>
      <small>${role.description}</small>
      <div class="tag-row">${role.focus.map((tag) => `<span class="tag">${tag}</span>`).join("")}</div>
    </button>
  `;
}

function skillCardMarkup(skill: SkillCard, installed: boolean) {
  const disabled = build.skills.disabled.includes(skill.id);
  const statusClass = disabled ? "skill-card--disabled" : installed ? "skill-card--enabled" : "";
  return `
    <article class="skill-card ${statusClass}">
      <div class="skill-card__top">
        <div>
          <strong>${skill.name}</strong>
          <small>${installed ? (disabled ? "已停用" : "已启用") : "待装配"}</small>
        </div>
        <div class="stack stack--tight">
          ${
            installed
              ? `<button class="chip-button ${disabled ? "chip-button--danger" : "chip-button--success"}" data-toggle-skill="${skill.id}">${disabled ? "停用" : "启用"}</button>
                 <button class="ghost-button ghost-button--small" data-remove-skill="${skill.id}">移除</button>`
              : `<button class="action-button action-button--small" data-add-skill="${skill.id}">加入</button>`
          }
        </div>
      </div>
      <small>${skill.description}</small>
    </article>
  `;
}

function taskMarkup(task: TaskPlan) {
  const latest = tasks[0]?.id === task.id;
  return `
    <article class="task-item ${latest ? "task-item--latest" : ""}">
      <strong>${task.prompt}</strong>
      <small>${new Date(task.createdAt).toLocaleString()}</small>
    </article>
  `;
}

function stationButtonMarkup(stationId: HomeStationId) {
  const station = stationInfo(stationId);
  const active = world.personaPanelStation === stationId ? "is-active" : "";
  const runtimeTag = runtime.stationId === stationId ? `<span class="nav-pill">执行中</span>` : "";
  const disabled = world.scene === "shared-world" && stationId !== "world-portal" ? "disabled" : "";
  return `
    <button class="station-button ${active}" data-station-id="${stationId}" ${disabled}>
      <span>
        <strong>${station.label}</strong>
        <small>${station.description}</small>
      </span>
      ${runtimeTag}
    </button>
  `;
}

function renderTopMeta() {
  const role = findRole(build.roleId);
  const success = `${runtime.metrics.taskSuccessRate.toFixed(1)}%`;
  topMeta.innerHTML = `
    <span class="badge">${role?.emoji || "🦞"} ${role?.className || build.roleId}</span>
    <span class="badge">Lv.${runtime.metrics.level} · XP ${runtime.metrics.xp}</span>
    <span class="badge">任务 ${runtime.metrics.tasksCompleted} · 成功率 ${success}</span>
    <span class="badge">在线 ${runtime.metrics.onlineMinutes} min</span>
    <span class="badge">Token ${runtime.metrics.tokenConsumption}</span>
    <span class="badge">${build.draftDirty ? "草稿未应用" : "已应用"}</span>
  `;
}

function renderSummaryCard() {
  const role = findRole(build.roleId);
  summaryCard.innerHTML = `
    <div class="summary-card__hero">
      <div>
        <span class="eyebrow">CURRENT BUILD</span>
        <h2>${role?.emoji || "🦞"} ${role?.title || build.roleId}</h2>
        <p>${role?.description || ""}</p>
      </div>
      <div class="summary-card__signal ${world.connection.openclawReachable ? "is-online" : "is-offline"}">
        ${world.connection.openclawReachable ? "Gateway 在线" : "Gateway 离线"}
      </div>
    </div>
    <div class="summary-grid">
      <article class="summary-pill"><span>规则</span><strong>${build.routing.tokenRule}</strong></article>
      <article class="summary-pill"><span>路由</span><strong>${build.routing.modelRoute}</strong></article>
      <article class="summary-pill"><span>高级模型</span><strong>${build.routing.advancedModel}</strong></article>
      <article class="summary-pill"><span>技能数</span><strong>${build.skills.installed.length}</strong></article>
      <article class="summary-pill"><span>当前动作</span><strong>${runtime.state}</strong></article>
      <article class="summary-pill"><span>工位</span><strong>${stationInfo(runtime.stationId).label}</strong></article>
    </div>
    <div class="tag-row">${(role?.focus || []).map((tag) => `<span class="tag">${tag}</span>`).join("")}</div>
  `;
}

function renderStationNav() {
  stationNav.innerHTML = (Object.keys(HOME_STATIONS) as HomeStationId[])
    .map(stationButtonMarkup)
    .join("");
  stationNav.querySelectorAll("[data-station-id]").forEach((element) => {
    element.addEventListener("click", async () => {
      const stationId = (element as HTMLElement).dataset.stationId as HomeStationId;
      if (world.scene === "shared-world" && stationId !== "world-portal") return;
      world.personaPanelStation = stationId;
      renderAll();
      const response = await api.setStation(stationId);
      world = response.world;
      renderAll();
    });
  });
}

function renderRolePanel() {
  const role = findRole(build.roleId);
  panelTitle.textContent = "职业台";
  panelHint.textContent = "切换职业只修改草稿，保存并应用后才真正落地。";
  panelBody.innerHTML = `
    <section class="panel-section panel-section--tight">
      <div class="panel-section__lead">
        <div>
          <h3>${role?.emoji || "🦞"} 当前草稿职业</h3>
          <p class="muted">${role?.description || ""}</p>
        </div>
        <div class="tag-row">${(role?.focus || []).map((tag) => `<span class="tag">${tag}</span>`).join("")}</div>
      </div>
      <div class="role-list">${roles.map(roleButtonMarkup).join("")}</div>
    </section>
    <section class="panel-section panel-section--tight">
      <h3>身份档案</h3>
      <div class="grid-two">
        <div class="field"><label>助手名称</label><input id="assistantName" value="${build.identity.assistantName}" /></div>
        <div class="field"><label>如何称呼你</label><input id="userName" value="${build.identity.userName}" /></div>
        <div class="field"><label>地区</label><input id="region" value="${build.identity.region}" /></div>
        <div class="field"><label>时区</label><input id="timezone" value="${build.identity.timezone}" /></div>
      </div>
      <div class="field"><label>主要目标</label><textarea id="goal">${build.identity.goal}</textarea></div>
      <div class="grid-two">
        <div class="field"><label>人格性格</label><input id="personality" value="${build.identity.personality}" /></div>
        <div class="field"><label>工作方式</label><input id="workStyle" value="${build.identity.workStyle}" /></div>
      </div>
    </section>
    <section class="panel-section panel-section--tight">
      <h3>规则与模型路由</h3>
      <div class="grid-three">
        <div class="field">
          <label>模型路由</label>
          <select id="modelRoute">
            ${["balanced", "analysis", "research", "codex", "growth", "creative"]
              .map(
                (item) =>
                  `<option value="${item}" ${build.routing.modelRoute === item ? "selected" : ""}>${item}</option>`,
              )
              .join("")}
          </select>
        </div>
        <div class="field">
          <label>规则档位</label>
          <select id="tokenRule">
            ${["low", "medium", "high"]
              .map(
                (item) =>
                  `<option value="${item}" ${build.routing.tokenRule === item ? "selected" : ""}>${item}</option>`,
              )
              .join("")}
          </select>
        </div>
        <div class="field">
          <label>高级模型</label>
          <input id="advancedModel" value="${build.routing.advancedModel}" />
        </div>
      </div>
    </section>
  `;

  panelBody.querySelectorAll("[data-role-id]").forEach((element) => {
    element.addEventListener("click", () => {
      rolePreset((element as HTMLElement).dataset.roleId as RoleId);
      setFlash("职业草稿已切换，等待保存或应用。", "warning");
      renderAll();
    });
  });
}

function renderSkillsPanel() {
  panelTitle.textContent = "技能书架";
  panelHint.textContent = "已装技能可启停/移除，备选技能来自本地技能仓。";
  panelBody.innerHTML = `
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>已安装技能</h3>
        <span class="muted">${catalog.installed.length} 项</span>
      </div>
      <div class="skill-list skill-list--short">${catalog.installed.map((skill) => skillCardMarkup(skill, true)).join("")}</div>
    </section>
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>备选技能库</h3>
        <span class="muted">${catalog.reserve.length} 项</span>
      </div>
      <div class="skill-list skill-list--short">${catalog.reserve.slice(0, 60).map((skill) => skillCardMarkup(skill, false)).join("")}</div>
    </section>
  `;

  panelBody.querySelectorAll("[data-toggle-skill]").forEach((element) => {
    element.addEventListener("click", () => {
      const skillId = (element as HTMLElement).dataset.toggleSkill as string;
      if (build.skills.disabled.includes(skillId)) {
        build.skills.disabled = build.skills.disabled.filter((item) => item !== skillId);
      } else {
        build.skills.disabled = [...build.skills.disabled, skillId];
      }
      setFlash("技能状态已更新到草稿。", "warning");
      renderAll();
    });
  });

  panelBody.querySelectorAll("[data-remove-skill]").forEach((element) => {
    element.addEventListener("click", () => {
      const skillId = (element as HTMLElement).dataset.removeSkill as string;
      build.skills.installed = build.skills.installed.filter((item) => item !== skillId);
      build.skills.disabled = build.skills.disabled.filter((item) => item !== skillId);
      setFlash("技能已从草稿移除。", "warning");
      renderAll();
    });
  });

  panelBody.querySelectorAll("[data-add-skill]").forEach((element) => {
    element.addEventListener("click", () => {
      const skillId = (element as HTMLElement).dataset.addSkill as string;
      if (!build.skills.installed.includes(skillId)) {
        build.skills.installed = [...build.skills.installed, skillId];
      }
      setFlash("技能已加入草稿。", "warning");
      renderAll();
    });
  });
}

function renderEquipmentPanel() {
  const inspected = selectedEquipment(inspectedSlot);
  panelTitle.textContent = "装备工坊";
  panelHint.textContent = "人物构筑由模型、工具、API 与 MCP 组成，修改后需保存和应用。";
  panelBody.innerHTML = `
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>装备槽</h3>
        <span class="muted">点击装备槽查看说明</span>
      </div>
      <div class="equipment-layout">
        <div class="equipment-grid equipment-grid--full">
          ${SLOT_ORDER.map((slot) => {
            const selected = selectedEquipment(slot);
            return `
              <button class="equipment-slot ${inspectedSlot === slot ? "is-active" : ""}" data-inspect-slot="${slot}">
                <span>${slot}</span>
                <strong>${selected?.name || "未装备"}</strong>
              </button>
            `;
          }).join("")}
        </div>
        <article class="equipment-detail">
          <div class="panel-row">
            <div>
              <small class="muted">当前查看</small>
              <h3>${inspected?.name || inspectedSlot}</h3>
            </div>
            <span class="rarity rarity--${inspected?.rarity || "common"}">${inspected?.rarity || "common"}</span>
          </div>
          <p class="muted">${inspected?.description || "该部位尚未装备，可从下方列表选择合适的模型、工具或接口。"}</p>
          <div class="field">
            <label>切换 ${inspectedSlot}</label>
            <select id="equipmentSelect">
              <option value="">未装备</option>
              ${equipmentForSlot(inspectedSlot)
                .map(
                  (item) =>
                    `<option value="${item.id}" ${build.equipment.slots[inspectedSlot] === item.id ? "selected" : ""}>${item.name}</option>`,
                )
                .join("")}
            </select>
          </div>
        </article>
      </div>
    </section>
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>包裹库存</h3>
        <span class="muted">${draftInventoryItems().length} 件可选</span>
      </div>
      <div class="inventory-grid">
        ${draftInventoryItems()
          .slice(0, 24)
          .map(
            (item) => `
              <article class="inventory-card inventory-card--${item.rarity}">
                <strong>${item.name}</strong>
                <small>${item.type} · ${item.slot}</small>
              </article>
            `,
          )
          .join("")}
      </div>
    </section>
  `;

  panelBody.querySelectorAll("[data-inspect-slot]").forEach((element) => {
    element.addEventListener("click", () => {
      inspectedSlot = (element as HTMLElement).dataset.inspectSlot as EquipmentSlotId;
      renderEquipmentPanel();
    });
  });

  panelBody.querySelector("#equipmentSelect")?.addEventListener("change", (event) => {
    const target = event.currentTarget as HTMLSelectElement;
    build.equipment.slots[inspectedSlot] = target.value || undefined;
    refreshInventoryFromSlots();
    setFlash("装备槽草稿已更新。", "warning");
    renderAll();
  });
}

function renderTaskPanel() {
  panelTitle.textContent = "任务桌";
  panelHint.textContent = "任务派发后，龙虾会在基地中切换工位并实时回传执行状态。";
  panelBody.innerHTML = `
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>当前执行</h3>
        <span class="muted">${runtime.state}</span>
      </div>
      <div class="summary-grid summary-grid--narrow">
        <article class="summary-pill"><span>进度</span><strong>${runtime.progress}%</strong></article>
        <article class="summary-pill"><span>工位</span><strong>${stationInfo(runtime.stationId).label}</strong></article>
        <article class="summary-pill"><span>来源</span><strong>${runtime.source}</strong></article>
        <article class="summary-pill"><span>最近结果</span><strong>${runtime.lastResult}</strong></article>
      </div>
    </section>
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>任务记录</h3>
        <span class="muted">${tasks.length} 条</span>
      </div>
      <div class="task-list">${tasks.slice(0, 8).map(taskMarkup).join("") || `<p class="muted">暂无任务记录。</p>`}</div>
    </section>
  `;
}

function renderStatusPanel() {
  panelTitle.textContent = "状态镜";
  panelHint.textContent = "这里是构筑指标、运行状态与成长结果。";
  panelBody.innerHTML = `
    <section class="panel-section panel-section--tight">
      <div class="metric-grid metric-grid--full">
        <article class="metric-card"><strong>Lv.${runtime.metrics.level}</strong><small>XP ${runtime.metrics.xp}</small></article>
        <article class="metric-card"><strong>${runtime.metrics.onlineMinutes}</strong><small>在线分钟</small></article>
        <article class="metric-card"><strong>${runtime.metrics.tasksCompleted}</strong><small>已完成任务</small></article>
        <article class="metric-card"><strong>${runtime.metrics.taskSuccessRate.toFixed(1)}%</strong><small>任务成功率</small></article>
        <article class="metric-card"><strong>${runtime.metrics.skillUsageRate.toFixed(1)}%</strong><small>技能使用率</small></article>
        <article class="metric-card"><strong>${runtime.metrics.tokenConsumption}</strong><small>Token 消耗</small></article>
      </div>
    </section>
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>运行状态</h3>
        <span class="muted">${runtime.updatedAt}</span>
      </div>
      <div class="status-stack">
        <article class="status-line"><span>当前动作</span><strong>${runtime.state}</strong></article>
        <article class="status-line"><span>工位</span><strong>${stationInfo(runtime.stationId).label}</strong></article>
        <article class="status-line"><span>详细信息</span><strong>${runtime.detail}</strong></article>
        <article class="status-line"><span>Gateway</span><strong>${world.connection.openclawReachable ? "在线" : "离线"}</strong></article>
        <article class="status-line"><span>WebSocket 客户端</span><strong>${world.connection.wsClients}</strong></article>
      </div>
    </section>
  `;
}

function renderPortalPanel() {
  panelTitle.textContent = "世界传送门";
  panelHint.textContent = "第一阶段仅开放公共世界入口壳，用于验证未来世界结构。";
  panelBody.innerHTML = `
    <section class="panel-section panel-section--tight">
      <h3>Shared World Shell</h3>
      <p class="muted">${world.sharedWorld.message}</p>
      <div class="summary-grid summary-grid--narrow">
        <article class="summary-pill"><span>结构</span><strong>大厅 / 协作板 / 房间壳</strong></article>
        <article class="summary-pill"><span>同步</span><strong>第二阶段接入</strong></article>
      </div>
      <div class="footer-actions footer-actions--left">
        <button class="action-button" id="enterSharedWorld">进入 Shared World</button>
        <button class="ghost-button" id="returnHomeBase">返回 Home Base</button>
      </div>
    </section>
  `;

  panelBody.querySelector("#enterSharedWorld")?.addEventListener("click", async () => {
    const response = await api.setScene("shared-world");
    world = response.world;
    setFlash("已切换到 Shared World 壳场景。", "info");
    renderAll();
  });

  panelBody.querySelector("#returnHomeBase")?.addEventListener("click", async () => {
    const response = await api.setScene("home-base");
    world = response.world;
    setFlash("已返回 Home Base。", "info");
    renderAll();
  });
}

function syncFormFieldsIntoBuild() {
  const assistantName = panelBody.querySelector("#assistantName") as HTMLInputElement | null;
  if (!assistantName) return;
  build.identity = {
    assistantName: assistantName.value,
    userName: (panelBody.querySelector("#userName") as HTMLInputElement).value,
    region: (panelBody.querySelector("#region") as HTMLInputElement).value,
    timezone: (panelBody.querySelector("#timezone") as HTMLInputElement).value,
    goal: (panelBody.querySelector("#goal") as HTMLTextAreaElement).value,
    personality: (panelBody.querySelector("#personality") as HTMLInputElement).value,
    workStyle: (panelBody.querySelector("#workStyle") as HTMLInputElement).value,
  };
  build.routing = {
    ...build.routing,
    modelRoute: (panelBody.querySelector("#modelRoute") as HTMLSelectElement).value,
    tokenRule: (panelBody.querySelector("#tokenRule") as HTMLSelectElement)
      .value as BuildState["routing"]["tokenRule"],
    advancedModel: (panelBody.querySelector("#advancedModel") as HTMLInputElement).value,
  };
}

function renderTaskDock() {
  taskDock.innerHTML = `
    <div class="task-dock__header">
      <strong>任务派发</strong>
      <span class="muted">派发给当前龙虾，结果会回流到世界与状态镜。</span>
    </div>
    <div class="task-dock__row">
      <textarea id="taskPrompt" placeholder="例如：整理投资周报、输出部署排障清单、生成设计提案">${taskDraft}</textarea>
      <button class="action-button action-button--gold" id="dispatchTaskButton">派发</button>
    </div>
    <div class="task-dock__footer">
      <span class="muted">当前动作：${runtime.state} · ${runtime.detail}</span>
      <span class="muted">最近结果：${runtime.lastResult}</span>
    </div>
  `;

  taskDock.querySelector("#dispatchTaskButton")?.addEventListener("click", async () => {
    const prompt = (taskDock.querySelector("#taskPrompt") as HTMLTextAreaElement).value.trim();
    taskDraft = prompt;
    if (!prompt) {
      setFlash("请输入任务描述。", "warning");
      return;
    }
    try {
      const response = await api.dispatchTask(prompt);
      tasks = response.tasks;
      setFlash("任务已派发，等待世界反馈。", "success");
      renderAll();
    } catch (error) {
      setFlash(`派单失败: ${(error as Error).message}`, "warning");
    }
  });
}

function renderPanel() {
  const station = stationInfo(world.personaPanelStation);
  stationLabel.textContent = station.label;
  stationHint.textContent = station.description;

  switch (world.personaPanelStation) {
    case "role-altar":
      renderRolePanel();
      break;
    case "skill-shelf":
      renderSkillsPanel();
      break;
    case "equipment-forge":
      renderEquipmentPanel();
      break;
    case "task-desk":
      renderTaskPanel();
      break;
    case "status-mirror":
      renderStatusPanel();
      break;
    case "world-portal":
      renderPortalPanel();
      break;
  }
}

function renderSceneButtons() {
  document.querySelectorAll("[data-scene]").forEach((element) => {
    const button = element as HTMLButtonElement;
    button.classList.toggle("is-active", button.dataset.scene === world.scene);
  });
}

function renderAll() {
  renderTopMeta();
  renderSummaryCard();
  renderStationNav();
  renderSceneButtons();
  renderPanel();
  renderTaskDock();
  renderFlash();
  renderer?.setBuild(build);
  renderer?.setRuntime(runtime);
  renderer?.setWorld(world);
}

async function hydrateBuild() {
  const response = await api.build();
  build = response.build;
  roles = response.roles;
  catalog = {
    installed: response.skills.installed,
    reserve: response.skills.reserve,
    equipped: response.equipment.equipped,
    inventory: response.equipment.inventory,
  };
}

async function bootstrap() {
  await hydrateBuild();
  runtime = (await api.runtime()).runtime;
  world = (await api.world()).world;
  tasks = (await api.tasks()).tasks;
  const { WorldRenderer } = await import("./world.js");
  renderer = new WorldRenderer(worldCanvas, async (stationId: HomeStationId) => {
    world.personaPanelStation = stationId;
    renderAll();
    const response = await api.setStation(stationId);
    world = response.world;
    renderAll();
  });
  setFlash("World gateway 已连接。", world.connection.openclawReachable ? "success" : "info");
  renderAll();
}

document.querySelectorAll("[data-scene]").forEach((element) => {
  element.addEventListener("click", async () => {
    const scene = (element as HTMLElement).dataset.scene as WorldState["scene"];
    const response = await api.setScene(scene);
    world = response.world;
    if (scene === "shared-world") {
      world.personaPanelStation = "world-portal";
    }
    setFlash(scene === "shared-world" ? "进入 Shared World 壳场景。" : "返回 Home Base。", "info");
    renderAll();
  });
});

document.getElementById("saveDraftButton")?.addEventListener("click", async () => {
  syncFormFieldsIntoBuild();
  try {
    const response = await api.saveBuild(build);
    build = response.build;
    catalog = {
      installed: response.skills.installed,
      reserve: response.skills.reserve,
      equipped: response.equipment.equipped,
      inventory: response.equipment.inventory,
    };
    setFlash("草稿已保存到 world gateway。", "success");
    renderAll();
  } catch (error) {
    setFlash(`保存草稿失败: ${(error as Error).message}`, "warning");
  }
});

document.getElementById("applyBuildButton")?.addEventListener("click", async () => {
  syncFormFieldsIntoBuild();
  try {
    await api.saveBuild(build);
    const response = await api.applyBuild();
    build = response.build;
    catalog = {
      installed: response.skills.installed,
      reserve: response.skills.reserve,
      equipped: response.equipment.equipped,
      inventory: response.equipment.inventory,
    };
    setFlash("构筑已应用到 OpenClaw 适配层。", "success");
    renderAll();
  } catch (error) {
    setFlash(`应用失败: ${(error as Error).message}`, "warning");
  }
});

const socket = new WebSocket(
  `${window.location.protocol === "https:" ? "wss" : "ws"}://${window.location.host}/ws/world`,
);

socket.addEventListener("open", () => {
  setFlash("WebSocket 已连接，实时反馈已启用。", "success");
});

socket.addEventListener("close", () => {
  setFlash("WebSocket 已断开，等待刷新重连。", "warning");
});

socket.addEventListener("message", async (event) => {
  const payload = JSON.parse(event.data) as {
    type: string;
    build?: BuildState;
    runtime?: RuntimeState;
    tasks?: TaskPlan[];
    world?: WorldState;
  };
  if (payload.build) {
    await hydrateBuild();
  }
  if (payload.runtime) runtime = payload.runtime;
  if (payload.tasks) tasks = payload.tasks;
  if (payload.world) world = payload.world;
  renderAll();
});

void bootstrap();
