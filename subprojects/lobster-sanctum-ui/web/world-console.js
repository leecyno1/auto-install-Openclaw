const PERSONA_KEY = "openclaw.persona.role";
const COMMAND_CENTER_KEY = "openclaw.command.center";
const RUNTIME_PROJECTION_KEY = "openclaw.runtime.world";
const OFFICE_PLAQUE_STORAGE_KEY = "officePlaqueCustomTitle";
const STATUS_ENDPOINT = "/status";
const PAGE_PARAMS = new URLSearchParams(window.location.search);
const CATALOG_ENDPOINT = "/openclaw/catalog";
const routeLabelMap = {
  balanced: "均衡协作",
  analysis: "深度分析",
  research: "研究长文",
  codex: "工程交付",
  growth: "增长运营",
  creative: "创意生成",
};
const tokenRuleLabelMap = {
  none: "不注入",
  low: "低档规则",
  medium: "中档规则",
  high: "高档规则",
};
const skillPackLabelMap = {
  low: "基础默认包",
  medium: "中档技能包",
  high: "高档技能包",
};

const roleProfiles = {
  druid: { className: "通用总管", title: "万金油 · 德鲁伊" },
  assassin: { className: "投资分析", title: "分析员 · 刺客" },
  mage: { className: "研究学习", title: "研究者 · 大法师" },
  summoner: { className: "组织管理", title: "管理者 · 召唤师" },
  warrior: { className: "工程开发", title: "技术员 · 战士" },
  paladin: { className: "增长运营", title: "营销者 · 圣骑士" },
  archer: { className: "设计创意", title: "设计师 · 弓箭手" },
};

const stations = {
  role: { label: "职业", title: "职业", desc: "切换职业、办公室名称、规则和安全配置。", path: "./configure.html?tab=role" },
  skills: { label: "技能", title: "技能", desc: "管理已安装技能、备选技能库和默认技能包。", path: "./configure.html?tab=skills" },
  equipment: { label: "装备物品", title: "装备物品", desc: "查看人物装备、物品栏和当前套装说明。", path: "./configure.html?tab=equipment" },
  status: { label: "状态成长", title: "状态成长", desc: "只读查看运行状态、系统参数和成长经验。", path: "./configure.html?tab=status" },
  tasks: { label: "任务流程", title: "任务流程", desc: "保留标准工作流、奖励和未来星级框架。", path: "./configure.html?tab=tasks" },
};

let currentRole = "druid";
let currentStation = "role";
let currentRuntime = { state: "idle", detail: "等待任务", progress: 0, updatedAt: "-", officeName: "" };
let resizeTimer = null;
let serverRole = "";
let currentCatalogPayload = null;

function safeParse(value, fallback) {
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function notifyParent(type, payload) {
  if (window.parent && window.parent !== window) {
    window.parent.postMessage({ type, ...payload }, window.location.origin);
  }
}

function readRole() {
  const role =
    PAGE_PARAMS.get("role") ||
    serverRole ||
    window.localStorage.getItem(PERSONA_KEY) ||
    "druid";
  return roleProfiles[role] ? role : "druid";
}

function equipSlotsFromCatalog(payload) {
  const equipped = {};
  const items = Array.isArray(payload?.equipment) ? payload.equipment : [];
  items.forEach((item) => {
    const slot = String(item?.slot || "").trim();
    const id = String(item?.id || "").trim();
    if (!slot || !id || equipped[slot]) return;
    equipped[slot] = id;
  });
  return equipped;
}

function buildProjectionFromCatalog(payload) {
  if (!payload?.ok) return null;
  const role = roleProfiles[payload.role] ? payload.role : "druid";
  const roleState = readRoleState(role) || {};
  const meta = roleProfiles[role] || roleProfiles.druid;
  const installedSkills = Array.isArray(payload?.skills?.installed) ? payload.skills.installed : [];
  const dynamicEquipped = equipSlotsFromCatalog(payload);
  return {
    role,
    persona: {
      title: meta.title,
      className: meta.className,
    },
    build: {
      modelRoute: roleState.modelRoute || "balanced",
      tokenRule: roleState.tokenRule || "medium",
      skillPack: roleState.skillPack || "medium",
      installedSkills,
      equipped: Object.keys(roleState.equipped || {}).length ? roleState.equipped : dynamicEquipped,
    },
  };
}

function readRoleState(role) {
  const store = safeParse(window.localStorage.getItem(COMMAND_CENTER_KEY), {});
  return store?.[role] || null;
}

function defaultOfficeNameForRole(role = currentRole) {
  return `${(roleProfiles[role] || roleProfiles.druid).title}的办公室`;
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

function readProjection() {
  return safeParse(window.localStorage.getItem(RUNTIME_PROJECTION_KEY), null);
}

function normalizeRuntime(payload) {
  if (!payload || typeof payload !== "object") {
    return { state: "idle", detail: "等待任务", progress: 0, updatedAt: "-", officeName: "" };
  }
  return {
    state: String(payload.state || payload.status || "idle").toLowerCase(),
    detail: String(payload.detail || payload.message || payload.text || "等待任务"),
    progress: Number(payload.progress || 0),
    updatedAt: String(payload.updatedAt || payload.updated_at || "-"),
    officeName: String(payload.officeName || ""),
  };
}

function readOfficeName() {
  const role = currentRole;
  const runtimeOffice = sanitizeOfficePlaqueTitle(currentRuntime.officeName, role);
  if (runtimeOffice && runtimeOffice !== defaultOfficeNameForRole(role)) {
    return runtimeOffice;
  }
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

function activeSummary() {
  const role = currentRole;
  const projection = readProjection();
  const catalogProjection = buildProjectionFromCatalog(currentCatalogPayload);
  const roleState = readRoleState(role) || {};
  const meta = roleProfiles[role] || roleProfiles.druid;
  const build =
    catalogProjection?.role === role
      ? catalogProjection.build || {}
      : projection?.role === role
        ? projection.build || {}
        : {};
  const installedSkills = Array.isArray(build.installedSkills) ? build.installedSkills.length : Array.isArray(roleState.installedSkills) ? roleState.installedSkills.length : 0;
  const equippedCount = Object.values(build.equipped || roleState.equipped || {}).filter(Boolean).length;
  return {
    role,
    title: catalogProjection?.role === role ? catalogProjection.persona?.title || meta.title : projection?.role === role ? projection.persona?.title || meta.title : meta.title,
    className: catalogProjection?.role === role ? catalogProjection.persona?.className || meta.className : projection?.role === role ? projection.persona?.className || meta.className : meta.className,
    route: build.modelRoute || roleState.modelRoute || "balanced",
    rule: build.tokenRule || roleState.tokenRule || "medium",
    pack: build.skillPack || roleState.skillPack || "medium",
    buildText: `${installedSkills} 技能 / ${equippedCount} 装备`,
  };
}

async function hydrateCatalog() {
  try {
    const response = await fetch(CATALOG_ENDPOINT, { cache: "no-store" });
    if (!response.ok) return;
    const payload = await response.json();
    if (!payload?.ok) return;
    currentCatalogPayload = payload;
    serverRole = roleProfiles[payload.role] ? payload.role : "";
    if (!PAGE_PARAMS.get("role") && serverRole) {
      currentRole = serverRole;
      window.localStorage.setItem(PERSONA_KEY, serverRole);
    }
  } catch {
    // ignore and fall back to local storage
  }
}

function buildFrameUrl(station) {
  const target = stations[station] || stations.role;
  const url = new URL(target.path, window.location.href);
  url.searchParams.set("embedded", "1");
  url.searchParams.set("chrome", "0");
  url.searchParams.set("theme", "pixel-house");
  url.searchParams.set("source", "world-console");
  url.searchParams.set("mode", station);
  url.searchParams.set("role", currentRole);
  return url.toString();
}

function setText(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = value;
}

function renderShell() {
  const summary = activeSummary();
  const stateLabelMap = {
    idle: "待命",
    writing: "工作中",
    researching: "检索中",
    executing: "执行中",
    syncing: "同步中",
    error: "报警中",
  };
  const stateLabel = stateLabelMap[currentRuntime.state] || currentRuntime.state;
  const routeLabel = routeLabelMap[summary.route] || summary.route || "均衡协作";
  const ruleLabel = tokenRuleLabelMap[summary.rule] || summary.rule || "中档规则";
  const packLabel = skillPackLabelMap[summary.pack] || summary.pack || "中档技能包";
  setText("worldConsoleOfficeLabel", readOfficeName());
  setText("worldConsoleRoleTitle", summary.title);
  setText("worldConsoleRoleClass", `${summary.className} · ${routeLabel}`);
  setText("worldConsoleStatusLabel", currentRuntime.detail || stateLabel);
  setText("worldConsoleSummaryLine1", `${summary.buildText}`);
  setText("worldConsoleSummaryLine2", `${routeLabel} · ${ruleLabel} · ${packLabel}`);
  setText("worldConsoleSummaryLine3", `${stations[currentStation]?.title || "职业"} · ${stateLabel} · ${Math.max(0, Math.min(100, currentRuntime.progress || 0))}%`);
  document.querySelectorAll(".world-console-tabs button[data-station]").forEach((button) => {
    button.classList.toggle("active", button.dataset.station === currentStation);
  });
  const avatar = document.getElementById("worldConsoleAvatar");
  if (avatar) avatar.dataset.state = currentRuntime.state || "idle";
}

function syncFrameHeight() {
  const frame = document.getElementById("worldConsoleFrame");
  if (!frame) return;
  try {
    const doc = frame.contentDocument;
    if (!doc) return;
    const shell = doc.querySelector(".config-shell, .loadout-shell, .runtime-shell, .app-shell");
    const activePanel = doc.querySelector(".tab-panel.active");
    const shellHeight = shell?.scrollHeight || 0;
    const panelHeight = activePanel?.scrollHeight || 0;
    const bodyHeight = doc.body?.scrollHeight || 0;
    const rootHeight = doc.documentElement?.scrollHeight || 0;
    const nextHeight = shellHeight > 0
      ? Math.max(520, shellHeight, panelHeight)
      : Math.max(520, bodyHeight, rootHeight);
    frame.style.height = `${Math.min(nextHeight + 2, 980)}px`;
  } catch {
    frame.style.height = "620px";
  }
}

function renderStation(station) {
  currentStation = stations[station] ? station : "role";
  const frame = document.getElementById("worldConsoleFrame");
  if (frame) frame.src = buildFrameUrl(currentStation);
  renderShell();
  notifyParent("lobster-world-console-station", { station: currentStation });
}

async function fetchStatus() {
  try {
    const resp = await fetch(STATUS_ENDPOINT, { cache: "no-store" });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    currentRuntime = normalizeRuntime(await resp.json());
    renderShell();
    notifyParent("lobster-world-console-status", currentRuntime);
  } catch (error) {
    currentRuntime = normalizeRuntime({ state: "error", detail: `状态读取失败：${error.message}`, progress: 0, updatedAt: "-" });
    renderShell();
  }
}

function bindEvents() {
  document.querySelectorAll(".world-console-tabs button[data-station]").forEach((button) => {
    button.addEventListener("click", () => renderStation(button.dataset.station));
  });
  const frame = document.getElementById("worldConsoleFrame");
  if (frame) {
    frame.addEventListener("load", () => {
      window.clearInterval(resizeTimer);
      syncFrameHeight();
      resizeTimer = window.setInterval(syncFrameHeight, 900);
    });
  }
  window.addEventListener("storage", () => {
    currentRole = readRole();
    renderShell();
  });
}

async function init() {
  await hydrateCatalog();
  currentRole = readRole();
  const requested = PAGE_PARAMS.get("station") || PAGE_PARAMS.get("mode") || "role";
  bindEvents();
  renderStation(stations[requested] ? requested : requested === "levels" ? "status" : requested === "items" ? "equipment" : "role");
  await fetchStatus();
  window.setInterval(fetchStatus, 4000);
  renderShell();
}

window.addEventListener("DOMContentLoaded", () => {
  init().catch(() => {
    currentRole = readRole();
    bindEvents();
    renderStation("role");
    fetchStatus();
  });
});
