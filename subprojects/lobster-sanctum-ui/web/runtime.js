const PERSONA_KEY = "openclaw.persona.role";
const COMMAND_CENTER_KEY = "openclaw.command.center";
const PROJECTION_KEY = "openclaw.runtime.world";
const SETTINGS_KEY = "openclaw.runtime.settings";
const ASSET_PACK_KEY = "openclaw.runtime.asset-pack";
const ASSET_MANIFEST_URL = "./runtime-assets/manifest.json";
const LOG_CAPACITY = 42;

const ADAPTER_PROFILES = [
  { id: "projection-api", label: "Projection API", note: "官方轻后端投影通道（推荐）", defaultEndpoint: "http://127.0.0.1:19100/runtime/state" },
  { id: "local-feed", label: "Local Feed", note: "读取 runtime-feed.json（推荐起步）", defaultEndpoint: "./runtime-feed.json" },
  { id: "star-office", label: "Star Office", note: "兼容 /status 返回结构", defaultEndpoint: "http://127.0.0.1:19000/status" },
  { id: "openclaw", label: "OpenClaw", note: "启发式解析 OpenClaw 运行数据", defaultEndpoint: "http://127.0.0.1:13145/status" },
  { id: "auto", label: "Auto", note: "自动探测常见字段并映射", defaultEndpoint: "" },
  { id: "generic", label: "Generic JSON", note: "通过路径手动指定 state/detail/progress", defaultEndpoint: "" },
];

const DEFAULT_STATE_PATHS = [
  "state",
  "status",
  "phase",
  "runtime.state",
  "data.state",
  "data.status",
  "data.runtime.state",
  "result.state",
  "payload.state",
  "agent.state",
  "agent.status",
];

const DEFAULT_DETAIL_PATHS = [
  "detail",
  "message",
  "text",
  "runtime.detail",
  "data.detail",
  "data.message",
  "data.runtime.detail",
  "result.detail",
  "payload.detail",
  "task.detail",
];

const DEFAULT_PROGRESS_PATHS = [
  "progress",
  "runtime.progress",
  "data.progress",
  "data.runtime.progress",
  "result.progress",
  "payload.progress",
];

const roleProfiles = {
  druid: { title: "万金油 · 德鲁伊" },
  assassin: { title: "分析员 · 刺客" },
  mage: { title: "研究者 · 大法师" },
  summoner: { title: "管理者 · 召唤师" },
  warrior: { title: "技术员 · 战士" },
  paladin: { title: "营销者 · 圣骑士" },
  archer: { title: "设计师 · 弓箭手" },
};

const stateDefs = [
  { id: "idle", label: "待命", zone: "breakroom", x: 10, y: 22 },
  { id: "writing", label: "文档整理", zone: "writing", x: 36, y: 36 },
  { id: "researching", label: "情报检索", zone: "research", x: 37, y: 67 },
  { id: "executing", label: "执行任务", zone: "execute", x: 63, y: 66 },
  { id: "syncing", label: "同步中", zone: "sync", x: 84, y: 37 },
  { id: "error", label: "故障修复", zone: "error", x: 84, y: 68 },
];

const phaseDefs = [
  { id: "researching", label: "检索" },
  { id: "writing", label: "整理" },
  { id: "executing", label: "执行" },
  { id: "syncing", label: "同步" },
  { id: "idle", label: "待命" },
  { id: "error", label: "修复" },
];

const stateMap = Object.fromEntries(stateDefs.map((item) => [item.id, item]));

let pollTimer = null;
let currentRole = "druid";
let runtimeProjection = null;
let selectedManualState = "idle";
let runtimeAgents = [];
let runtimeMissions = [];
let teamPollCounter = 0;
let lastTeamPullError = "";
let agentsEventSource = null;
let agentsStreamRetryTimer = null;
let lastAgentEventId = 0;
let assetManifest = null;
let currentAssetPackId = "";
let currentAssetPack = null;
let currentAssetBodyClass = "";
const loadedAssetEntryKeys = new Set();

function safeParse(value, fallback) {
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function nowText() {
  return new Date().toLocaleString("zh-CN", { hour12: false });
}

function readRole() {
  const params = new URLSearchParams(window.location.search);
  const role = params.get("role") || window.localStorage.getItem(PERSONA_KEY) || "druid";
  return roleProfiles[role] ? role : "druid";
}

function readCommandStore() {
  return safeParse(window.localStorage.getItem(COMMAND_CENTER_KEY), {});
}

function readProjection() {
  return safeParse(window.localStorage.getItem(PROJECTION_KEY), null);
}

function saveProjection(data) {
  window.localStorage.setItem(PROJECTION_KEY, JSON.stringify(data));
}

function readSelectedAssetPack() {
  return String(window.localStorage.getItem(ASSET_PACK_KEY) || "").trim();
}

function saveSelectedAssetPack(packId) {
  window.localStorage.setItem(ASSET_PACK_KEY, String(packId || ""));
}

function resolveAssetUrl(path) {
  const raw = String(path || "").trim();
  if (!raw) return "";
  try {
    return new URL(raw, window.location.href).toString();
  } catch {
    return "";
  }
}

function setWorldPackHint(text) {
  const el = document.getElementById("worldPackHint");
  if (el) el.textContent = text;
}

function setWorldPackStats(text) {
  const el = document.getElementById("worldPackStats");
  if (el) el.textContent = text;
}

function getPackById(packId) {
  if (!assetManifest?.packs?.length) return null;
  return assetManifest.packs.find((item) => item.id === packId) || null;
}

function addCssAssetOnce(entryKey, href) {
  if (!href || loadedAssetEntryKeys.has(entryKey)) return;
  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = href;
  link.dataset.assetEntryKey = entryKey;
  document.head.appendChild(link);
  loadedAssetEntryKeys.add(entryKey);
}

function preloadImageAssetOnce(entryKey, href) {
  if (!href || loadedAssetEntryKeys.has(entryKey)) return;
  const img = new Image();
  img.decoding = "async";
  img.loading = "eager";
  img.src = href;
  loadedAssetEntryKeys.add(entryKey);
}

function loadPackAssetEntry(packId, entry) {
  const type = String(entry?.type || "").toLowerCase();
  const path = entry?.path;
  const entryId = String(entry?.id || path || `${type}:unknown`);
  const entryKey = `${packId}:${entryId}`;
  const href = resolveAssetUrl(path);
  if (!href) return;
  if (type === "css") {
    addCssAssetOnce(entryKey, href);
    return;
  }
  if (type === "image") {
    preloadImageAssetOnce(entryKey, href);
    return;
  }
  if (type === "script" && !loadedAssetEntryKeys.has(entryKey)) {
    const script = document.createElement("script");
    script.src = href;
    script.defer = true;
    script.dataset.assetEntryKey = entryKey;
    document.head.appendChild(script);
    loadedAssetEntryKeys.add(entryKey);
  }
}

function applyPackBodyClass(pack) {
  const body = document.body;
  if (currentAssetBodyClass && body.classList.contains(currentAssetBodyClass)) {
    body.classList.remove(currentAssetBodyClass);
  }
  const nextClass = String(pack?.bodyClass || "").trim();
  if (nextClass) {
    body.classList.add(nextClass);
  }
  currentAssetBodyClass = nextClass;
}

function ensurePackModeAssets(stateId) {
  if (!currentAssetPack || !Array.isArray(currentAssetPack.assets)) return;
  currentAssetPack.assets
    .filter((entry) => String(entry?.mode || "") === String(stateId || ""))
    .forEach((entry) => loadPackAssetEntry(currentAssetPack.id, entry));
}

function renderWorldPackOptions() {
  const select = document.getElementById("worldPackSelect");
  if (!select) return;
  const packs = Array.isArray(assetManifest?.packs) ? assetManifest.packs : [];
  if (!packs.length) {
    select.innerHTML = `<option value="">no pack</option>`;
    select.disabled = true;
    setWorldPackHint("未发现资源包清单，运行核心样式。");
    setWorldPackStats("资源统计: 0 包 / 0 资源");
    return;
  }
  select.disabled = false;
  select.innerHTML = packs
    .map((item) => `<option value="${item.id}">${item.name}</option>`)
    .join("");
  const preferred = readSelectedAssetPack() || assetManifest.defaultPack || packs[0].id;
  select.value = getPackById(preferred)?.id || packs[0].id;
}

function updateWorldPackHint(pack) {
  if (!pack) {
    setWorldPackHint("资源包不可用，使用核心模式。");
    setWorldPackStats("资源统计: 0 包 / 0 资源");
    return;
  }
  const desc = String(pack.description || "无描述");
  const assets = Number(pack?.totals?.assets || 0);
  const bytes = Number(pack?.totals?.bytes || 0);
  setWorldPackHint(`${pack.name} · ${desc}`);
  setWorldPackStats(`资源统计: ${assets} 资源 / ${(bytes / 1024).toFixed(1)} KB`);
}

async function loadAssetManifest() {
  try {
    const resp = await fetch(ASSET_MANIFEST_URL, { cache: "no-store" });
    if (!resp.ok) {
      throw new Error(`manifest HTTP ${resp.status}`);
    }
    assetManifest = await resp.json();
    renderWorldPackOptions();
  } catch (error) {
    assetManifest = null;
    renderWorldPackOptions();
    setWorldPackHint(`资源包清单加载失败: ${error.message}`);
  }
}

function applyAssetPack(packId, { announce = true } = {}) {
  const pack = getPackById(packId);
  if (!pack) {
    setWorldPackHint("资源包不存在，保持核心样式。");
    return;
  }
  currentAssetPackId = pack.id;
  currentAssetPack = pack;
  saveSelectedAssetPack(pack.id);
  applyPackBodyClass(pack);
  updateWorldPackHint(pack);
  if (runtimeProjection?.build) {
    runtimeProjection.build.assetPack = pack.id;
    saveProjection(runtimeProjection);
  }

  if (Array.isArray(pack.assets)) {
    pack.assets
      .filter((entry) => String(entry?.mode || "base") === "base")
      .forEach((entry) => loadPackAssetEntry(pack.id, entry));
  }
  const stateId = runtimeProjection?.runtime?.state || "idle";
  ensurePackModeAssets(stateId);
  if (announce) {
    appendLog(`资源包已切换 -> ${pack.id}`, "sync");
  }
}

function defaultSettings() {
  return {
    profile: "projection-api",
    endpoint: "http://127.0.0.1:19100/runtime/state",
    statePath: "",
    detailPath: "",
    progressPath: "",
    autoPoll: true,
    pollIntervalMs: 3000,
  };
}

function normalizeSettings(raw) {
  const base = defaultSettings();
  const merged = { ...base, ...(raw || {}) };
  if (!ADAPTER_PROFILES.some((item) => item.id === merged.profile)) {
    merged.profile = base.profile;
  }
  const interval = Number(merged.pollIntervalMs);
  merged.pollIntervalMs = Number.isFinite(interval) ? Math.min(60000, Math.max(1000, interval)) : base.pollIntervalMs;
  merged.autoPoll = Boolean(merged.autoPoll);
  merged.endpoint = String(merged.endpoint || "");
  merged.statePath = String(merged.statePath || "");
  merged.detailPath = String(merged.detailPath || "");
  merged.progressPath = String(merged.progressPath || "");
  return merged;
}

function readSettings() {
  return normalizeSettings(safeParse(window.localStorage.getItem(SETTINGS_KEY), null));
}

function saveSettings(settings) {
  window.localStorage.setItem(SETTINGS_KEY, JSON.stringify(normalizeSettings(settings)));
}

function createDefaultProjection(role, roleState) {
  const installedSkills = roleState?.installedSkills || [];
  return {
    version: 1,
    generatedAt: new Date().toISOString(),
    role,
    persona: {
      title: roleProfiles[role]?.title || role,
    },
    build: {
      modelRoute: roleState?.modelRoute || "balanced",
      skillPack: roleState?.skillPack || "medium",
      tokenRule: roleState?.tokenRule || "medium",
      assetPack: roleState?.assetPack || "core",
      installedSkills,
      equipped: roleState?.equipped || {},
      activeSynergies: roleState?.activeSynergies || [],
    },
    runtime: {
      state: "idle",
      detail: "运行世界初始化完成，等待任务。",
      progress: 0,
      source: "local",
      updatedAt: new Date().toISOString(),
    },
    logs: [],
  };
}

function buildLevelByProjection(projection) {
  const skillCount = projection.build.installedSkills?.length || 0;
  const toolCount = Object.values(projection.build.equipped || {}).filter(Boolean).length;
  const synergyCount = projection.build.activeSynergies?.length || 0;
  const xp = skillCount * 90 + toolCount * 140 + synergyCount * 260;
  return Math.max(1, Math.floor(xp / 320) + 1);
}

function appendLog(message, type = "info") {
  const logs = runtimeProjection.logs || [];
  logs.unshift({ message, type, at: nowText() });
  runtimeProjection.logs = logs.slice(0, LOG_CAPACITY);
  renderLogs();
  saveProjection(runtimeProjection);
}

function renderLogs() {
  const list = document.getElementById("runtimeLogList");
  const logs = runtimeProjection.logs || [];
  list.innerHTML = "";
  if (!logs.length) {
    list.innerHTML = `<li class="runtime-log-item"><p>暂无日志</p><small>${nowText()}</small></li>`;
    return;
  }
  logs.forEach((entry) => {
    const li = document.createElement("li");
    li.className = "runtime-log-item";
    li.innerHTML = `<p>${entry.message}</p><small>${entry.at}</small>`;
    list.appendChild(li);
  });
}

function setAvatarByState(stateId) {
  const state = stateMap[stateId] || stateMap.idle;
  const avatar = document.getElementById("worldAvatar");
  const stage = document.getElementById("worldStage");
  avatar.style.left = `${state.x}%`;
  avatar.style.top = `${state.y}%`;
  avatar.setAttribute("data-runtime-state", state.id);
  stage.setAttribute("data-runtime-state", state.id);
  document.querySelectorAll(".zone-card").forEach((zone) => {
    zone.classList.toggle("active", zone.dataset.zone === state.zone);
  });
}

function renderPhaseStrip() {
  const strip = document.getElementById("phaseStrip");
  strip.innerHTML = phaseDefs
    .map(
      (phase) => `
        <article class="phase-card" data-phase-id="${phase.id}">
          <span>${phase.label}</span>
          <small>${phase.id}</small>
        </article>
      `,
    )
    .join("");
}

function updatePhaseStrip(stateId, progress) {
  const order = ["researching", "writing", "executing", "syncing"];
  const currentIndex = order.indexOf(stateId);
  document.querySelectorAll(".phase-card").forEach((card) => {
    const phaseId = card.dataset.phaseId;
    card.classList.remove("active", "done", "danger");
    if (phaseId === "error" && stateId === "error") {
      card.classList.add("active", "danger");
      return;
    }
    if (phaseId === "idle" && stateId === "idle") {
      card.classList.add("active");
      return;
    }
    const phaseIndex = order.indexOf(phaseId);
    if (currentIndex >= 0 && phaseIndex >= 0 && phaseIndex < currentIndex) {
      card.classList.add("done");
    }
    if (phaseId === stateId) {
      card.classList.add("active");
    }
  });
  const progressText = document.getElementById("runtimeProgressText");
  const progressFill = document.getElementById("runtimeProgressFill");
  const normalized = Math.max(0, Math.min(100, Number(progress) || 0));
  progressText.textContent = `${normalized}%`;
  progressFill.style.width = `${normalized}%`;
}

function renderMeta() {
  const projection = runtimeProjection;
  const role = projection.role;
  const toolCount = Object.values(projection.build.equipped || {}).filter(Boolean).length;
  const level = buildLevelByProjection(projection);
  document.getElementById("metaRoleTitle").textContent = projection.persona.title || roleProfiles[role]?.title || role;
  document.getElementById("metaModelRoute").textContent = projection.build.modelRoute || "balanced";
  document.getElementById("metaSkillCount").textContent = String(projection.build.installedSkills?.length || 0);
  document.getElementById("metaToolCount").textContent = String(toolCount);
  document.getElementById("metaSynergyCount").textContent = String(projection.build.activeSynergies?.length || 0);
  document.getElementById("metaLevel").textContent = `Lv.${level}`;
  document.getElementById("avatarName").textContent = (projection.persona.title || "LOBSTER").replace(/\s+/g, " ").slice(0, 20);
}

function renderRuntimeState() {
  const runtime = runtimeProjection.runtime || {};
  const state = stateMap[runtime.state] || stateMap.idle;
  selectedManualState = state.id;
  document.getElementById("runtimeStateText").textContent = `${state.label} · ${runtime.source || "local"}`;
  document.getElementById("runtimeDetailText").textContent = runtime.detail || "等待任务。";
  document.getElementById("runtimeUpdateText").textContent = `更新时间: ${runtime.updatedAt ? new Date(runtime.updatedAt).toLocaleString("zh-CN", { hour12: false }) : "-"}`;
  document.getElementById("worldBubble").textContent = runtime.detail || state.label;
  setAvatarByState(runtime.state || "idle");
  ensurePackModeAssets(runtime.state || "idle");
  updatePhaseStrip(runtime.state || "idle", runtime.progress || 0);
  const detailInput = document.getElementById("detailInput");
  if (!detailInput.value.trim()) {
    detailInput.value = runtime.detail || "";
  }
  document.querySelectorAll(".runtime-state-button").forEach((button) => {
    button.classList.toggle("active", button.dataset.stateId === selectedManualState);
  });
}

function renderStateButtons() {
  const holder = document.getElementById("runtimeStateButtons");
  holder.innerHTML = "";
  stateDefs.forEach((item) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "runtime-state-button";
    button.textContent = `${item.label} (${item.id})`;
    button.dataset.stateId = item.id;
    button.addEventListener("click", () => {
      selectedManualState = item.id;
      applyRuntimeState(item.id, document.getElementById("detailInput").value.trim() || `${item.label}中`, "manual");
    });
    holder.appendChild(button);
  });
}

function applyRuntimeState(stateId, detail, source, progress = 0) {
  const finalState = stateMap[stateId] ? stateId : "idle";
  const finalDetail = detail || `${stateMap[finalState].label}中`;
  const finalProgress = Number(progress) || 0;
  const previous = runtimeProjection.runtime || {};
  const isSamePoll =
    source === "poll" &&
    previous.state === finalState &&
    previous.detail === finalDetail &&
    Number(previous.progress || 0) === finalProgress;
  if (isSamePoll) {
    return;
  }
  runtimeProjection.runtime = {
    state: finalState,
    detail: finalDetail,
    progress: finalProgress,
    source,
    updatedAt: new Date().toISOString(),
  };
  renderRuntimeState();
  saveProjection(runtimeProjection);
  appendLog(`状态切换 -> ${finalState} (${source})`, source === "poll" ? "sync" : "info");
}

function getByPath(obj, path) {
  if (!path) return undefined;
  const chunks = path.split(".").map((item) => item.trim()).filter(Boolean);
  let cur = obj;
  for (const chunk of chunks) {
    if (cur == null || typeof cur !== "object" || !(chunk in cur)) {
      return undefined;
    }
    cur = cur[chunk];
  }
  return cur;
}

function firstNonEmptyByPaths(obj, paths) {
  for (const path of paths) {
    const value = getByPath(obj, path);
    if (value !== undefined && value !== null && value !== "") {
      return value;
    }
  }
  return undefined;
}

function normalizeRawState(rawState, rawDetail) {
  const stateText = String(rawState || "").trim().toLowerCase();
  if (stateText && stateMap[stateText]) return stateText;

  const buckets = [
    { id: "idle", keys: ["idle", "ready", "standby", "wait", "rest", "sleep", "待命", "空闲", "等待"] },
    { id: "writing", keys: ["writing", "draft", "compose", "summarize", "doc", "文档", "写作", "整理"] },
    { id: "researching", keys: ["research", "search", "lookup", "crawl", "find", "检索", "搜索", "调研"] },
    { id: "executing", keys: ["executing", "running", "tool", "command", "coding", "build", "执行", "运行", "调用"] },
    { id: "syncing", keys: ["sync", "upload", "push", "deliver", "commit", "同步", "推送", "提交"] },
    { id: "error", keys: ["error", "fail", "failed", "panic", "timeout", "exception", "报错", "失败", "异常", "超时"] },
  ];

  for (const bucket of buckets) {
    if (bucket.keys.some((key) => stateText.includes(key))) {
      return bucket.id;
    }
  }

  const detailText = String(rawDetail || "").trim().toLowerCase();
  for (const bucket of buckets) {
    if (bucket.keys.some((key) => detailText.includes(key))) {
      return bucket.id;
    }
  }
  return null;
}

function normalizeProgress(raw) {
  const value = Number(raw);
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, Math.round(value)));
}

function normalizePayloadByProfile(data, settings) {
  const profile = settings.profile;
  if (profile === "generic") {
    const stateRaw = getByPath(data, settings.statePath);
    const detailRaw = getByPath(data, settings.detailPath);
    const progressRaw = getByPath(data, settings.progressPath);
    const state = normalizeRawState(stateRaw, detailRaw);
    if (!state) return null;
    return {
      state,
      detail: String(detailRaw || `${stateMap[state].label}中`),
      progress: normalizeProgress(progressRaw),
    };
  }

  if (profile === "projection-api") {
    const payload = data?.data && typeof data.data === "object" ? data.data : data;
    const state = normalizeRawState(payload?.state || payload?.phase, payload?.detail || payload?.message);
    if (!state) return null;
    return {
      state,
      detail: String(payload?.detail || payload?.message || `${stateMap[state].label}中`),
      progress: normalizeProgress(payload?.progress),
    };
  }

  if (profile === "local-feed" || profile === "star-office") {
    const state = normalizeRawState(data?.state, data?.detail || data?.message);
    if (!state) return null;
    return {
      state,
      detail: String(data?.detail || data?.message || `${stateMap[state].label}中`),
      progress: normalizeProgress(data?.progress),
    };
  }

  const stateCandidates = [
    ...DEFAULT_STATE_PATHS,
    ...(settings.statePath ? [settings.statePath] : []),
  ];
  const detailCandidates = [
    ...DEFAULT_DETAIL_PATHS,
    ...(settings.detailPath ? [settings.detailPath] : []),
  ];
  const progressCandidates = [
    ...DEFAULT_PROGRESS_PATHS,
    ...(settings.progressPath ? [settings.progressPath] : []),
  ];
  const stateRaw = firstNonEmptyByPaths(data, stateCandidates);
  const detailRaw = firstNonEmptyByPaths(data, detailCandidates);
  const progressRaw = firstNonEmptyByPaths(data, progressCandidates);
  const state = normalizeRawState(stateRaw, detailRaw);

  if (!state) return null;
  return {
    state,
    detail: String(detailRaw || `${stateMap[state].label}中`),
    progress: normalizeProgress(progressRaw),
  };
}

function resolveProjectionEndpoint(stateEndpoint, targetPath) {
  const raw = String(stateEndpoint || "").trim();
  if (!raw) return "";
  try {
    const url = new URL(raw, window.location.href);
    url.pathname = targetPath;
    url.search = "";
    url.hash = "";
    return url.toString();
  } catch {
    return "";
  }
}

function normalizeAgentRow(item) {
  return {
    agent_id: String(item?.agent_id || item?.id || ""),
    name: String(item?.name || item?.agent_id || item?.id || "unknown-agent"),
    role: String(item?.role || "worker"),
    state: String(item?.state || "idle"),
    detail: String(item?.detail || item?.message || ""),
    task_id: String(item?.task_id || ""),
    progress: normalizeProgress(item?.progress),
    status: String(item?.status || "online"),
    updated_at: item?.updated_at || item?.last_seen || "",
    tool: String(item?.tool || ""),
    model: String(item?.model || ""),
  };
}

function setAgentStreamStatus(mode, detail = "") {
  const el = document.getElementById("agentStreamStatus");
  if (!el) return;
  const suffix = detail ? ` · ${detail}` : "";
  el.textContent = `传输: ${mode}${suffix}`;
}

function missionStatusWeight(status) {
  const map = { running: 0, pending: 1, blocked: 2, done: 3, canceled: 4 };
  return map[status] ?? 9;
}

function normalizeMissionRow(item) {
  return {
    mission_id: String(item?.mission_id || item?.id || ""),
    title: String(item?.title || item?.mission_id || "未命名任务"),
    status: String(item?.status || "pending"),
    progress: normalizeProgress(item?.progress),
    owner_agent_id: String(item?.owner_agent_id || item?.owner || ""),
    summary: String(item?.summary || item?.detail || ""),
    updated_at: item?.updated_at || "",
  };
}

function renderAgentList() {
  const list = document.getElementById("runtimeAgentList");
  const rows = [...runtimeAgents].sort((a, b) => {
    if (a.status !== b.status) return a.status === "online" ? -1 : 1;
    return new Date(b.updated_at || 0).getTime() - new Date(a.updated_at || 0).getTime();
  });
  document.getElementById("agentTotalCount").textContent = String(rows.length);
  document.getElementById("agentOnlineCount").textContent = String(rows.filter((x) => x.status === "online").length);
  document.getElementById("agentOfflineCount").textContent = String(rows.filter((x) => x.status !== "online").length);

  list.innerHTML = "";
  if (!rows.length) {
    list.innerHTML = `<li class="runtime-agent-item"><p>暂无协作代理在线。</p><small class="runtime-agent-meta">${nowText()}</small></li>`;
    return;
  }
  rows.forEach((agent) => {
    const li = document.createElement("li");
    li.className = "runtime-agent-item";
    const badgeClass = agent.status === "online" ? "online" : "offline";
    const safeDetail = agent.detail || `${agent.state} 中`;
    const meta = [agent.task_id ? `task: ${agent.task_id}` : "", agent.tool ? `tool: ${agent.tool}` : "", agent.model ? `model: ${agent.model}` : ""]
      .filter(Boolean)
      .join(" · ");
    li.innerHTML = `
      <div class="runtime-agent-head">
        <div>
          <strong>${agent.name}</strong>
          <small class="runtime-agent-role">${agent.role}</small>
        </div>
        <span class="runtime-agent-badge ${badgeClass}">${agent.status}</span>
      </div>
      <p>${safeDetail}</p>
      <small class="runtime-agent-meta">${agent.state} · ${agent.progress}%${meta ? ` · ${meta}` : ""}</small>
    `;
    list.appendChild(li);
  });
}

function renderMissionList() {
  const list = document.getElementById("runtimeMissionList");
  const rows = [...runtimeMissions].sort((a, b) => {
    const w = missionStatusWeight(a.status) - missionStatusWeight(b.status);
    if (w !== 0) return w;
    return new Date(b.updated_at || 0).getTime() - new Date(a.updated_at || 0).getTime();
  });
  document.getElementById("missionRunningCount").textContent = String(rows.filter((x) => x.status === "running").length);
  document.getElementById("missionBlockedCount").textContent = String(rows.filter((x) => x.status === "blocked").length);
  document.getElementById("missionDoneCount").textContent = String(rows.filter((x) => x.status === "done").length);

  list.innerHTML = "";
  if (!rows.length) {
    list.innerHTML = `<li class="runtime-mission-item"><p>暂无协作任务。</p><small class="runtime-mission-meta">${nowText()}</small></li>`;
    return;
  }
  rows.forEach((mission) => {
    const li = document.createElement("li");
    li.className = "runtime-mission-item";
    const status = mission.status || "pending";
    const owner = mission.owner_agent_id ? `owner: ${mission.owner_agent_id}` : "owner: unassigned";
    li.innerHTML = `
      <div class="runtime-mission-head">
        <strong>${mission.title}</strong>
        <span class="runtime-mission-badge ${status}">${status}</span>
      </div>
      <p>${mission.summary || "暂无任务说明"}</p>
      <small class="runtime-mission-meta">${owner} · progress: ${mission.progress}%</small>
      <div class="runtime-mission-progress"><span style="width:${mission.progress}%"></span></div>
    `;
    list.appendChild(li);
  });
}

function upsertRuntimeAgent(agent) {
  if (!agent?.agent_id) return;
  const idx = runtimeAgents.findIndex((item) => item.agent_id === agent.agent_id);
  if (idx >= 0) {
    runtimeAgents[idx] = { ...runtimeAgents[idx], ...agent };
  } else {
    runtimeAgents.push(agent);
  }
}

function applyAgentStreamEvent(event) {
  if (!event || typeof event !== "object") return;
  const agentId = String(event.agent_id || "");
  if (!agentId) return;
  const state = String(event.state || event.phase || "idle");
  const payload = normalizeAgentRow({
    agent_id: agentId,
    name: event.name || agentId,
    role: event.role || "worker",
    state,
    detail: event.detail || event.message || "",
    progress: event.progress,
    task_id: event.task_id || "",
    tool: event.tool || "",
    model: event.model || "",
    status: event.type === "leave" ? "offline" : "online",
    updated_at: event.created_at || new Date().toISOString(),
  });
  upsertRuntimeAgent(payload);
  renderAgentList();
}

function clearAgentsStreamRetry() {
  if (agentsStreamRetryTimer) {
    window.clearTimeout(agentsStreamRetryTimer);
    agentsStreamRetryTimer = null;
  }
}

function closeAgentsStream() {
  clearAgentsStreamRetry();
  if (agentsEventSource) {
    agentsEventSource.close();
    agentsEventSource = null;
  }
}

function scheduleAgentsStreamRetry(endpoint) {
  clearAgentsStreamRetry();
  agentsStreamRetryTimer = window.setTimeout(() => {
    startAgentsStream(endpoint, { retrying: true });
  }, 3000);
}

function startAgentsStream(baseEndpoint, { retrying = false } = {}) {
  closeAgentsStream();
  const streamUrl = resolveProjectionEndpoint(baseEndpoint, "/runtime/agents/stream");
  if (!streamUrl) {
    setAgentStreamStatus("polling");
    return;
  }
  const fullUrl = `${streamUrl}${streamUrl.includes("?") ? "&" : "?"}since_id=${encodeURIComponent(String(lastAgentEventId || 0))}`;
  try {
    const source = new EventSource(fullUrl);
    agentsEventSource = source;
    setAgentStreamStatus("sse", retrying ? "reconnect" : "live");
    source.addEventListener("agent", (evt) => {
      const id = Number(evt.lastEventId || 0);
      if (Number.isFinite(id) && id > 0) {
        lastAgentEventId = Math.max(lastAgentEventId, id);
      }
      try {
        const data = JSON.parse(evt.data || "{}");
        applyAgentStreamEvent(data);
      } catch {
        // ignore malformed packet
      }
    });
    source.addEventListener("ping", () => {
      setAgentStreamStatus("sse", "heartbeat");
    });
    source.addEventListener("hello", () => {
      setAgentStreamStatus("sse", "connected");
    });
    source.onerror = () => {
      setAgentStreamStatus("polling", "fallback");
      if (agentsEventSource) {
        agentsEventSource.close();
        agentsEventSource = null;
      }
      scheduleAgentsStreamRetry(baseEndpoint);
    };
  } catch {
    setAgentStreamStatus("polling");
  }
}

function pullTeamSnapshotOnce({ silent = true } = {}) {
  const settings = readAdapterForm();
  if (settings.profile !== "projection-api") {
    runtimeAgents = [];
    runtimeMissions = [];
    renderAgentList();
    renderMissionList();
    return Promise.resolve();
  }
  const agentsUrl = resolveProjectionEndpoint(settings.endpoint, "/runtime/agents");
  const missionsUrl = resolveProjectionEndpoint(settings.endpoint, "/runtime/missions");
  if (!agentsUrl || !missionsUrl) {
    return Promise.resolve();
  }
  return Promise.all([
    fetch(agentsUrl, { cache: "no-store" }).then((resp) => (resp.ok ? resp.json() : Promise.reject(new Error(`agents HTTP ${resp.status}`)))),
    fetch(missionsUrl, { cache: "no-store" }).then((resp) => (resp.ok ? resp.json() : Promise.reject(new Error(`missions HTTP ${resp.status}`)))),
  ])
    .then(([agentsPayload, missionsPayload]) => {
      runtimeAgents = Array.isArray(agentsPayload?.data) ? agentsPayload.data.map(normalizeAgentRow) : [];
      runtimeMissions = Array.isArray(missionsPayload?.data) ? missionsPayload.data.map(normalizeMissionRow) : [];
      renderAgentList();
      renderMissionList();
      lastTeamPullError = "";
    })
    .catch((error) => {
      if (!silent && error.message !== lastTeamPullError) {
        appendLog(`协作面板拉取失败：${error.message}`, "error");
      }
      lastTeamPullError = error.message;
    });
}

function readAdapterForm() {
  return normalizeSettings({
    profile: document.getElementById("adapterProfileSelect").value,
    endpoint: document.getElementById("endpointInput").value.trim(),
    statePath: document.getElementById("statePathInput").value.trim(),
    detailPath: document.getElementById("detailPathInput").value.trim(),
    progressPath: document.getElementById("progressPathInput").value.trim(),
    autoPoll: document.getElementById("autoPollToggle").checked,
    pollIntervalMs: Number(document.getElementById("pollIntervalInput").value),
  });
}

function fillAdapterProfileOptions(settings) {
  const select = document.getElementById("adapterProfileSelect");
  select.innerHTML = ADAPTER_PROFILES.map((item) => `<option value="${item.id}">${item.label}</option>`).join("");
  select.value = settings.profile;
  updateAdapterHint(settings.profile);
}

function updateAdapterHint(profileId) {
  const profile = ADAPTER_PROFILES.find((item) => item.id === profileId) || ADAPTER_PROFILES[0];
  document.getElementById("adapterHint").textContent = profile.note;
}

function pullRemoteStateOnce({ includeTeam = false, silentTeam = true } = {}) {
  const settings = readAdapterForm();
  const endpoint = settings.endpoint;
  if (!endpoint) {
    appendLog("轮询失败：未填写接口地址", "error");
    return;
  }
  fetch(endpoint, { cache: "no-store" })
    .then((resp) => {
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}`);
      }
      return resp.json();
    })
    .then((data) => {
      const normalized = normalizePayloadByProfile(data, settings);
      if (!normalized) {
        appendLog("轮询成功但未识别出可映射状态，请调整适配器配置。", "error");
        return;
      }
      applyRuntimeState(normalized.state, normalized.detail, "poll", normalized.progress);
      if (includeTeam) {
        pullTeamSnapshotOnce({ silent: silentTeam });
      }
    })
    .catch((error) => {
      appendLog(`轮询失败：${error.message}`, "error");
    });
}

function restartPolling() {
  if (pollTimer) {
    window.clearInterval(pollTimer);
    pollTimer = null;
  }
  teamPollCounter = 0;
  const settings = readAdapterForm();
  if (settings.profile === "projection-api" && settings.endpoint) {
    startAgentsStream(settings.endpoint);
  } else {
    closeAgentsStream();
    setAgentStreamStatus("polling");
  }
  if (!settings.autoPoll) return;
  pollTimer = window.setInterval(() => {
    teamPollCounter += 1;
    const includeTeam = teamPollCounter % 2 === 1;
    pullRemoteStateOnce({ includeTeam, silentTeam: true });
  }, settings.pollIntervalMs);
}

function refreshFromBuild() {
  const store = readCommandStore();
  const roleState = store[currentRole] || {};
  runtimeProjection.build = {
    ...(runtimeProjection.build || {}),
    modelRoute: roleState.modelRoute || runtimeProjection.build.modelRoute || "balanced",
    skillPack: roleState.skillPack || runtimeProjection.build.skillPack || "medium",
    tokenRule: roleState.tokenRule || runtimeProjection.build.tokenRule || "medium",
    assetPack: roleState.assetPack || runtimeProjection.build.assetPack || currentAssetPackId || "core",
    installedSkills: roleState.installedSkills || runtimeProjection.build.installedSkills || [],
    equipped: roleState.equipped || runtimeProjection.build.equipped || {},
    activeSynergies: runtimeProjection.build.activeSynergies || [],
  };
  runtimeProjection.persona.title = roleProfiles[currentRole]?.title || currentRole;
  runtimeProjection.generatedAt = new Date().toISOString();
  saveProjection(runtimeProjection);
  renderMeta();
  appendLog("已从 Stage III 构筑刷新运行快照", "sync");
}

function exportRuntimeSnapshot() {
  const blob = new Blob([JSON.stringify(runtimeProjection, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `openclaw-runtime-${currentRole}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
  appendLog("已导出运行快照 JSON", "sync");
}

function applyProfileDefaultsIfNeeded(profileId) {
  const profile = ADAPTER_PROFILES.find((item) => item.id === profileId);
  if (!profile) return;
  const endpointInput = document.getElementById("endpointInput");
  if (!endpointInput.value.trim() && profile.defaultEndpoint) {
    endpointInput.value = profile.defaultEndpoint;
  }
}

function bindRuntimeActions() {
  renderPhaseStrip();
  updatePhaseStrip(runtimeProjection.runtime?.state || "idle", runtimeProjection.runtime?.progress || 0);
  renderStateButtons();
  document.getElementById("applyStateBtn").addEventListener("click", () => {
    const detail = document.getElementById("detailInput").value.trim() || stateMap[selectedManualState].label;
    applyRuntimeState(selectedManualState, detail, "manual");
  });
  document.getElementById("pollNowBtn").addEventListener("click", () => {
    pullRemoteStateOnce({ includeTeam: true, silentTeam: false });
  });
  document.getElementById("refreshBuildBtn").addEventListener("click", () => {
    refreshFromBuild();
  });
  document.getElementById("exportRuntimeBtn").addEventListener("click", () => {
    exportRuntimeSnapshot();
  });
  document.getElementById("applyWorldPackBtn").addEventListener("click", () => {
    const nextPackId = document.getElementById("worldPackSelect").value;
    applyAssetPack(nextPackId, { announce: true });
  });
  document.getElementById("worldPackSelect").addEventListener("change", () => {
    const nextPackId = document.getElementById("worldPackSelect").value;
    const pack = getPackById(nextPackId);
    updateWorldPackHint(pack);
  });

  const persistAdapterSettings = (withRestart = true) => {
    const settings = readAdapterForm();
    saveSettings(settings);
    updateAdapterHint(settings.profile);
    if (settings.profile !== "projection-api") {
      closeAgentsStream();
      setAgentStreamStatus("polling");
      runtimeAgents = [];
      runtimeMissions = [];
      renderAgentList();
      renderMissionList();
    } else {
      startAgentsStream(settings.endpoint);
      pullTeamSnapshotOnce({ silent: true });
    }
    if (withRestart) restartPolling();
  };

  document.getElementById("adapterProfileSelect").addEventListener("change", () => {
    const profileId = document.getElementById("adapterProfileSelect").value;
    updateAdapterHint(profileId);
    applyProfileDefaultsIfNeeded(profileId);
    persistAdapterSettings();
    appendLog(`适配器已切换为 ${profileId}`, "sync");
  });

  [
    "endpointInput",
    "statePathInput",
    "detailPathInput",
    "progressPathInput",
    "pollIntervalInput",
    "autoPollToggle",
  ].forEach((id) => {
    const el = document.getElementById(id);
    const eventName = id === "autoPollToggle" ? "change" : "change";
    el.addEventListener(eventName, () => {
      persistAdapterSettings();
    });
  });
}

function hydrateAdapterForm(settings) {
  fillAdapterProfileOptions(settings);
  document.getElementById("endpointInput").value = settings.endpoint || "";
  document.getElementById("statePathInput").value = settings.statePath || "";
  document.getElementById("detailPathInput").value = settings.detailPath || "";
  document.getElementById("progressPathInput").value = settings.progressPath || "";
  document.getElementById("autoPollToggle").checked = Boolean(settings.autoPoll);
  document.getElementById("pollIntervalInput").value = String(settings.pollIntervalMs || 3000);
}

async function bootstrap() {
  currentRole = readRole();
  window.localStorage.setItem(PERSONA_KEY, currentRole);
  const store = readCommandStore();
  const roleState = store[currentRole] || {};
  const cached = readProjection();
  runtimeProjection = cached && cached.role === currentRole ? cached : createDefaultProjection(currentRole, roleState);
  runtimeProjection.role = currentRole;
  runtimeProjection.persona = runtimeProjection.persona || {};
  runtimeProjection.persona.title = runtimeProjection.persona.title || roleProfiles[currentRole]?.title || currentRole;
  runtimeProjection.build = runtimeProjection.build || {};
  runtimeProjection.logs = runtimeProjection.logs || [];
  saveProjection(runtimeProjection);

  const settings = readSettings();
  hydrateAdapterForm(settings);
  document.getElementById("runtimeToConfigure").href = `./configure.html?role=${encodeURIComponent(currentRole)}`;

  await loadAssetManifest();
  if (assetManifest?.packs?.length) {
    const packSelect = document.getElementById("worldPackSelect");
    const preferredPack =
      runtimeProjection?.build?.assetPack ||
      readSelectedAssetPack() ||
      assetManifest.defaultPack ||
      assetManifest.packs[0].id;
    const targetPack = getPackById(preferredPack) || assetManifest.packs[0];
    if (packSelect && targetPack?.id) {
      packSelect.value = targetPack.id;
    }
    applyAssetPack(targetPack?.id, { announce: false });
  } else {
    setWorldPackHint("未加载资源包，保持核心样式。");
    setWorldPackStats("资源统计: 0 包 / 0 资源");
  }

  renderMeta();
  renderLogs();
  renderAgentList();
  renderMissionList();
  bindRuntimeActions();
  renderRuntimeState();

  appendLog("运行世界已启动", "info");
  setAgentStreamStatus("polling", "init");
  pullTeamSnapshotOnce({ silent: true });
  restartPolling();
}

window.addEventListener("beforeunload", () => {
  closeAgentsStream();
});

bootstrap().catch((error) => {
  console.error("[runtime] bootstrap failed", error);
});
