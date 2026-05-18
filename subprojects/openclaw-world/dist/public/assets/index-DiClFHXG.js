(function(){const t=document.createElement("link").relList;if(t&&t.supports&&t.supports("modulepreload"))return;for(const o of document.querySelectorAll('link[rel="modulepreload"]'))b(o);new MutationObserver(o=>{for(const d of o)if(d.type==="childList")for(const u of d.addedNodes)u.tagName==="LINK"&&u.rel==="modulepreload"&&b(u)}).observe(document,{childList:!0,subtree:!0});function a(o){const d={};return o.integrity&&(d.integrity=o.integrity),o.referrerPolicy&&(d.referrerPolicy=o.referrerPolicy),o.crossOrigin==="use-credentials"?d.credentials="include":o.crossOrigin==="anonymous"?d.credentials="omit":d.credentials="same-origin",d}function b(o){if(o.ep)return;o.ep=!0;const d=a(o);fetch(o.href,d)}})();const Q="modulepreload",Y=function(e){return"/"+e},T={},Z=function(t,a,b){let o=Promise.resolve();if(a&&a.length>0){let z=function(m){return Promise.all(m.map(k=>Promise.resolve(k).then(E=>({status:"fulfilled",value:E}),E=>({status:"rejected",reason:E}))))};document.getElementsByTagName("link");const u=document.querySelector("meta[property=csp-nonce]"),v=u?.nonce||u?.getAttribute("nonce");o=z(a.map(m=>{if(m=Y(m),m in T)return;T[m]=!0;const k=m.endsWith(".css"),E=k?'[rel="stylesheet"]':"";if(document.querySelector(`link[href="${m}"]${E}`))return;const h=document.createElement("link");if(h.rel=k?"stylesheet":Q,k||(h.as="script"),h.crossOrigin="",h.href=m,v&&h.setAttribute("nonce",v),document.head.appendChild(h),k)return new Promise((V,K)=>{h.addEventListener("load",V),h.addEventListener("error",()=>K(new Error(`Unable to preload CSS for ${m}`)))})}))}function d(u){const v=new Event("vite:preloadError",{cancelable:!0});if(v.payload=u,window.dispatchEvent(v),!v.defaultPrevented)throw u}return o.then(u=>{for(const v of u||[])v.status==="rejected"&&d(v.reason);return t().catch(d)})},ee=[{id:"focus-crown",name:"Focus Crown",description:"保持上下文与任务聚焦。",type:"app",rarity:"magic",slot:"head"},{id:"ops-harness",name:"Ops Harness",description:"稳定任务分派与组织调度。",type:"tool",rarity:"rare",slot:"head"},{id:"notebook-vault",name:"Notebook Vault",description:"学术知识库与笔记入口。",type:"app",rarity:"rare",slot:"head"},{id:"memo-ring",name:"Memo Ring",description:"记忆、注释和上下文收纳。",type:"app",rarity:"magic",slot:"amulet"},{id:"search-array",name:"Search Array",description:"搜索 API 聚合阵列。",type:"api",rarity:"rare",slot:"mainhand"},{id:"sheet-engine",name:"Sheet Engine",description:"XLSX 分析与表格建模。",type:"tool",rarity:"magic",slot:"offhand"},{id:"document-forge",name:"Document Forge",description:"文档与演示稿输出工具链。",type:"tool",rarity:"magic",slot:"offhand"},{id:"github-mcp",name:"GitHub MCP",description:"仓库读写与协同。",type:"mcp",rarity:"rare",slot:"offhand"},{id:"agentmail-suite",name:"AgentMail Suite",description:"邮件往来与客户沟通。",type:"app",rarity:"magic",slot:"offhand"},{id:"shell-runner",name:"Shell Runner",description:"命令行、脚本和文件操作。",type:"tool",rarity:"common",slot:"mainhand"},{id:"image-studio",name:"Image Studio",description:"图像生成与视觉迭代。",type:"tool",rarity:"rare",slot:"mainhand"},{id:"minimax-2-7",name:"MiniMax 2.7",description:"默认主力模型，平衡速度与质量。",type:"model",rarity:"epic",slot:"chest"},{id:"claude-main",name:"Claude Main",description:"长文本与复杂推理。",type:"model",rarity:"legendary",slot:"chest"},{id:"codex-core",name:"Codex Core",description:"工程实现与调试核心。",type:"model",rarity:"legendary",slot:"chest"},{id:"gemini-vision",name:"Gemini Vision",description:"多模态理解与图像任务。",type:"model",rarity:"legendary",slot:"chest"},{id:"cron-orb",name:"Cron Orb",description:"定时任务与后台巡检。",type:"tool",rarity:"rare",slot:"belt"},{id:"campaign-belt",name:"Campaign Belt",description:"营销节奏和分发配置。",type:"app",rarity:"magic",slot:"belt"},{id:"field-boots",name:"Field Boots",description:"提高情报巡航和执行节奏。",type:"tool",rarity:"common",slot:"boots"}],j={"role-altar":{id:"role-altar",label:"职业台",description:"查看并切换七个职业。"},"skill-shelf":{id:"skill-shelf",label:"技能书架",description:"管理已装技能与备选技能。"},"equipment-forge":{id:"equipment-forge",label:"装备工坊",description:"配置模型、API、MCP 与工具。"},"task-desk":{id:"task-desk",label:"任务桌",description:"派发任务并追踪执行状态。"},"status-mirror":{id:"status-mirror",label:"状态镜",description:"查看成长与运行指标。"},"world-portal":{id:"world-portal",label:"世界传送门",description:"进入未来的公共世界入口。"}};async function g(e,t){const a=await fetch(e,{cache:"no-store",headers:{"content-type":"application/json"},...t});if(!a.ok)throw new Error(`HTTP ${a.status}`);return await a.json()}const p={build:()=>g("/api/build"),saveBuild:e=>g("/api/build",{method:"PUT",body:JSON.stringify(e)}),applyBuild:()=>g("/api/build/apply",{method:"POST",body:"{}"}),runtime:()=>g("/api/runtime"),tasks:()=>g("/api/tasks"),world:()=>g("/api/world/state"),setScene:e=>g("/api/world/scene",{method:"POST",body:JSON.stringify({scene:e})}),setStation:e=>g("/api/world/station",{method:"POST",body:JSON.stringify({stationId:e})}),dispatchTask:e=>g("/api/tasks",{method:"POST",body:JSON.stringify({prompt:e})})},te=["head","amulet","chest","mainhand","offhand","belt","boots"],A=document.getElementById("app");if(!A)throw new Error("missing app root");let s,n,l,L=[],w=[],y={installed:[],reserve:[],equipped:[],inventory:[]},I="",f="chest",W="正在连接 world gateway...",D="info";A.innerHTML=`
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
`;const se=document.getElementById("worldCanvas"),ae=document.getElementById("topMeta"),ne=document.getElementById("summaryCard"),R=document.getElementById("stationNav"),$=document.getElementById("panelTitle"),S=document.getElementById("panelHint"),i=document.getElementById("panelBody"),P=document.getElementById("taskDock"),ie=document.getElementById("stationLabel"),le=document.getElementById("stationHint"),N=document.getElementById("flashBanner");let B;function r(e,t="info"){W=e,D=t,F()}function F(){N.textContent=W,N.className=`signal signal--${D}`}function C(e){return L.find(t=>t.id===e)||L[0]}function q(e){return j[e]}function _(){return[...y.equipped,...y.inventory].sort((e,t)=>e.name.localeCompare(t.name))}function oe(e){return _().filter(t=>t.slot===e)}function x(){const e=new Set(Object.values(s.equipment.slots).filter(Boolean));return _().filter(t=>!e.has(t.id))}function U(){const e=new Set(Object.values(s.equipment.slots).filter(Boolean));s.equipment.inventory=ee.filter(t=>!e.has(t.id)).map(t=>t.id)}function re(e){const t=C(e);t&&(s.roleId=e,s.identity.goal=t.description,s.routing.modelRoute=t.recommendedModelRoute,s.routing.tokenRule=e==="druid"?"low":"medium",s.routing.skillPack=e==="druid"?"low":"medium",s.routing.advancedModel=e==="warrior"?"gpt-5.4":"claude-main",s.skills.installed=[...t.starterSkills],s.skills.disabled=[],s.equipment.slots={chest:t.starterEquipment.chest||"minimax-2-7",...t.starterEquipment},U())}function O(e){const t=s.equipment.slots[e];return _().find(a=>a.id===t)||null}function ce(e){return`
    <button class="role-card ${e.id===s.roleId?"is-active":""}" data-role-id="${e.id}">
      <div class="role-card__top">
        <strong>${e.emoji} ${e.title}</strong>
        <small>${e.className}</small>
      </div>
      <small>${e.description}</small>
      <div class="tag-row">${e.focus.map(a=>`<span class="tag">${a}</span>`).join("")}</div>
    </button>
  `}function H(e,t){const a=s.skills.disabled.includes(e.id);return`
    <article class="skill-card ${a?"skill-card--disabled":t?"skill-card--enabled":""}">
      <div class="skill-card__top">
        <div>
          <strong>${e.name}</strong>
          <small>${t?a?"已停用":"已启用":"待装配"}</small>
        </div>
        <div class="stack stack--tight">
          ${t?`<button class="chip-button ${a?"chip-button--danger":"chip-button--success"}" data-toggle-skill="${e.id}">${a?"停用":"启用"}</button>
                 <button class="ghost-button ghost-button--small" data-remove-skill="${e.id}">移除</button>`:`<button class="action-button action-button--small" data-add-skill="${e.id}">加入</button>`}
        </div>
      </div>
      <small>${e.description}</small>
    </article>
  `}function de(e){return`
    <article class="task-item ${w[0]?.id===e.id?"task-item--latest":""}">
      <strong>${e.prompt}</strong>
      <small>${new Date(e.createdAt).toLocaleString()}</small>
    </article>
  `}function pe(e){const t=q(e),a=l.personaPanelStation===e?"is-active":"",b=n.stationId===e?'<span class="nav-pill">执行中</span>':"",o=l.scene==="shared-world"&&e!=="world-portal"?"disabled":"";return`
    <button class="station-button ${a}" data-station-id="${e}" ${o}>
      <span>
        <strong>${t.label}</strong>
        <small>${t.description}</small>
      </span>
      ${b}
    </button>
  `}function ue(){const e=C(s.roleId),t=`${n.metrics.taskSuccessRate.toFixed(1)}%`;ae.innerHTML=`
    <span class="badge">${e?.emoji||"🦞"} ${e?.className||s.roleId}</span>
    <span class="badge">Lv.${n.metrics.level} · XP ${n.metrics.xp}</span>
    <span class="badge">任务 ${n.metrics.tasksCompleted} · 成功率 ${t}</span>
    <span class="badge">在线 ${n.metrics.onlineMinutes} min</span>
    <span class="badge">Token ${n.metrics.tokenConsumption}</span>
    <span class="badge">${s.draftDirty?"草稿未应用":"已应用"}</span>
  `}function me(){const e=C(s.roleId);ne.innerHTML=`
    <div class="summary-card__hero">
      <div>
        <span class="eyebrow">CURRENT BUILD</span>
        <h2>${e?.emoji||"🦞"} ${e?.title||s.roleId}</h2>
        <p>${e?.description||""}</p>
      </div>
      <div class="summary-card__signal ${l.connection.openclawReachable?"is-online":"is-offline"}">
        ${l.connection.openclawReachable?"Gateway 在线":"Gateway 离线"}
      </div>
    </div>
    <div class="summary-grid">
      <article class="summary-pill"><span>规则</span><strong>${s.routing.tokenRule}</strong></article>
      <article class="summary-pill"><span>路由</span><strong>${s.routing.modelRoute}</strong></article>
      <article class="summary-pill"><span>高级模型</span><strong>${s.routing.advancedModel}</strong></article>
      <article class="summary-pill"><span>技能数</span><strong>${s.skills.installed.length}</strong></article>
      <article class="summary-pill"><span>当前动作</span><strong>${n.state}</strong></article>
      <article class="summary-pill"><span>工位</span><strong>${q(n.stationId).label}</strong></article>
    </div>
    <div class="tag-row">${(e?.focus||[]).map(t=>`<span class="tag">${t}</span>`).join("")}</div>
  `}function ve(){R.innerHTML=Object.keys(j).map(pe).join(""),R.querySelectorAll("[data-station-id]").forEach(e=>{e.addEventListener("click",async()=>{const t=e.dataset.stationId;if(l.scene==="shared-world"&&t!=="world-portal")return;l.personaPanelStation=t,c(),l=(await p.setStation(t)).world,c()})})}function ge(){const e=C(s.roleId);$.textContent="职业台",S.textContent="切换职业只修改草稿，保存并应用后才真正落地。",i.innerHTML=`
    <section class="panel-section panel-section--tight">
      <div class="panel-section__lead">
        <div>
          <h3>${e?.emoji||"🦞"} 当前草稿职业</h3>
          <p class="muted">${e?.description||""}</p>
        </div>
        <div class="tag-row">${(e?.focus||[]).map(t=>`<span class="tag">${t}</span>`).join("")}</div>
      </div>
      <div class="role-list">${L.map(ce).join("")}</div>
    </section>
    <section class="panel-section panel-section--tight">
      <h3>身份档案</h3>
      <div class="grid-two">
        <div class="field"><label>助手名称</label><input id="assistantName" value="${s.identity.assistantName}" /></div>
        <div class="field"><label>如何称呼你</label><input id="userName" value="${s.identity.userName}" /></div>
        <div class="field"><label>地区</label><input id="region" value="${s.identity.region}" /></div>
        <div class="field"><label>时区</label><input id="timezone" value="${s.identity.timezone}" /></div>
      </div>
      <div class="field"><label>主要目标</label><textarea id="goal">${s.identity.goal}</textarea></div>
      <div class="grid-two">
        <div class="field"><label>人格性格</label><input id="personality" value="${s.identity.personality}" /></div>
        <div class="field"><label>工作方式</label><input id="workStyle" value="${s.identity.workStyle}" /></div>
      </div>
    </section>
    <section class="panel-section panel-section--tight">
      <h3>规则与模型路由</h3>
      <div class="grid-three">
        <div class="field">
          <label>模型路由</label>
          <select id="modelRoute">
            ${["balanced","analysis","research","codex","growth","creative"].map(t=>`<option value="${t}" ${s.routing.modelRoute===t?"selected":""}>${t}</option>`).join("")}
          </select>
        </div>
        <div class="field">
          <label>规则档位</label>
          <select id="tokenRule">
            ${["low","medium","high"].map(t=>`<option value="${t}" ${s.routing.tokenRule===t?"selected":""}>${t}</option>`).join("")}
          </select>
        </div>
        <div class="field">
          <label>高级模型</label>
          <input id="advancedModel" value="${s.routing.advancedModel}" />
        </div>
      </div>
    </section>
  `,i.querySelectorAll("[data-role-id]").forEach(t=>{t.addEventListener("click",()=>{re(t.dataset.roleId),r("职业草稿已切换，等待保存或应用。","warning"),c()})})}function ye(){$.textContent="技能书架",S.textContent="已装技能可启停/移除，备选技能来自本地技能仓。",i.innerHTML=`
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>已安装技能</h3>
        <span class="muted">${y.installed.length} 项</span>
      </div>
      <div class="skill-list skill-list--short">${y.installed.map(e=>H(e,!0)).join("")}</div>
    </section>
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>备选技能库</h3>
        <span class="muted">${y.reserve.length} 项</span>
      </div>
      <div class="skill-list skill-list--short">${y.reserve.slice(0,60).map(e=>H(e,!1)).join("")}</div>
    </section>
  `,i.querySelectorAll("[data-toggle-skill]").forEach(e=>{e.addEventListener("click",()=>{const t=e.dataset.toggleSkill;s.skills.disabled.includes(t)?s.skills.disabled=s.skills.disabled.filter(a=>a!==t):s.skills.disabled=[...s.skills.disabled,t],r("技能状态已更新到草稿。","warning"),c()})}),i.querySelectorAll("[data-remove-skill]").forEach(e=>{e.addEventListener("click",()=>{const t=e.dataset.removeSkill;s.skills.installed=s.skills.installed.filter(a=>a!==t),s.skills.disabled=s.skills.disabled.filter(a=>a!==t),r("技能已从草稿移除。","warning"),c()})}),i.querySelectorAll("[data-add-skill]").forEach(e=>{e.addEventListener("click",()=>{const t=e.dataset.addSkill;s.skills.installed.includes(t)||(s.skills.installed=[...s.skills.installed,t]),r("技能已加入草稿。","warning"),c()})})}function G(){const e=O(f);$.textContent="装备工坊",S.textContent="人物构筑由模型、工具、API 与 MCP 组成，修改后需保存和应用。",i.innerHTML=`
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>装备槽</h3>
        <span class="muted">点击装备槽查看说明</span>
      </div>
      <div class="equipment-layout">
        <div class="equipment-grid equipment-grid--full">
          ${te.map(t=>{const a=O(t);return`
              <button class="equipment-slot ${f===t?"is-active":""}" data-inspect-slot="${t}">
                <span>${t}</span>
                <strong>${a?.name||"未装备"}</strong>
              </button>
            `}).join("")}
        </div>
        <article class="equipment-detail">
          <div class="panel-row">
            <div>
              <small class="muted">当前查看</small>
              <h3>${e?.name||f}</h3>
            </div>
            <span class="rarity rarity--${e?.rarity||"common"}">${e?.rarity||"common"}</span>
          </div>
          <p class="muted">${e?.description||"该部位尚未装备，可从下方列表选择合适的模型、工具或接口。"}</p>
          <div class="field">
            <label>切换 ${f}</label>
            <select id="equipmentSelect">
              <option value="">未装备</option>
              ${oe(f).map(t=>`<option value="${t.id}" ${s.equipment.slots[f]===t.id?"selected":""}>${t.name}</option>`).join("")}
            </select>
          </div>
        </article>
      </div>
    </section>
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>包裹库存</h3>
        <span class="muted">${x().length} 件可选</span>
      </div>
      <div class="inventory-grid">
        ${x().slice(0,24).map(t=>`
              <article class="inventory-card inventory-card--${t.rarity}">
                <strong>${t.name}</strong>
                <small>${t.type} · ${t.slot}</small>
              </article>
            `).join("")}
      </div>
    </section>
  `,i.querySelectorAll("[data-inspect-slot]").forEach(t=>{t.addEventListener("click",()=>{f=t.dataset.inspectSlot,G()})}),i.querySelector("#equipmentSelect")?.addEventListener("change",t=>{const a=t.currentTarget;s.equipment.slots[f]=a.value||void 0,U(),r("装备槽草稿已更新。","warning"),c()})}function he(){$.textContent="任务桌",S.textContent="任务派发后，龙虾会在基地中切换工位并实时回传执行状态。",i.innerHTML=`
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>当前执行</h3>
        <span class="muted">${n.state}</span>
      </div>
      <div class="summary-grid summary-grid--narrow">
        <article class="summary-pill"><span>进度</span><strong>${n.progress}%</strong></article>
        <article class="summary-pill"><span>工位</span><strong>${q(n.stationId).label}</strong></article>
        <article class="summary-pill"><span>来源</span><strong>${n.source}</strong></article>
        <article class="summary-pill"><span>最近结果</span><strong>${n.lastResult}</strong></article>
      </div>
    </section>
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>任务记录</h3>
        <span class="muted">${w.length} 条</span>
      </div>
      <div class="task-list">${w.slice(0,8).map(de).join("")||'<p class="muted">暂无任务记录。</p>'}</div>
    </section>
  `}function fe(){$.textContent="状态镜",S.textContent="这里是构筑指标、运行状态与成长结果。",i.innerHTML=`
    <section class="panel-section panel-section--tight">
      <div class="metric-grid metric-grid--full">
        <article class="metric-card"><strong>Lv.${n.metrics.level}</strong><small>XP ${n.metrics.xp}</small></article>
        <article class="metric-card"><strong>${n.metrics.onlineMinutes}</strong><small>在线分钟</small></article>
        <article class="metric-card"><strong>${n.metrics.tasksCompleted}</strong><small>已完成任务</small></article>
        <article class="metric-card"><strong>${n.metrics.taskSuccessRate.toFixed(1)}%</strong><small>任务成功率</small></article>
        <article class="metric-card"><strong>${n.metrics.skillUsageRate.toFixed(1)}%</strong><small>技能使用率</small></article>
        <article class="metric-card"><strong>${n.metrics.tokenConsumption}</strong><small>Token 消耗</small></article>
      </div>
    </section>
    <section class="panel-section panel-section--tight">
      <div class="panel-row">
        <h3>运行状态</h3>
        <span class="muted">${n.updatedAt}</span>
      </div>
      <div class="status-stack">
        <article class="status-line"><span>当前动作</span><strong>${n.state}</strong></article>
        <article class="status-line"><span>工位</span><strong>${q(n.stationId).label}</strong></article>
        <article class="status-line"><span>详细信息</span><strong>${n.detail}</strong></article>
        <article class="status-line"><span>Gateway</span><strong>${l.connection.openclawReachable?"在线":"离线"}</strong></article>
        <article class="status-line"><span>WebSocket 客户端</span><strong>${l.connection.wsClients}</strong></article>
      </div>
    </section>
  `}function be(){$.textContent="世界传送门",S.textContent="第一阶段仅开放公共世界入口壳，用于验证未来世界结构。",i.innerHTML=`
    <section class="panel-section panel-section--tight">
      <h3>Shared World Shell</h3>
      <p class="muted">${l.sharedWorld.message}</p>
      <div class="summary-grid summary-grid--narrow">
        <article class="summary-pill"><span>结构</span><strong>大厅 / 协作板 / 房间壳</strong></article>
        <article class="summary-pill"><span>同步</span><strong>第二阶段接入</strong></article>
      </div>
      <div class="footer-actions footer-actions--left">
        <button class="action-button" id="enterSharedWorld">进入 Shared World</button>
        <button class="ghost-button" id="returnHomeBase">返回 Home Base</button>
      </div>
    </section>
  `,i.querySelector("#enterSharedWorld")?.addEventListener("click",async()=>{l=(await p.setScene("shared-world")).world,r("已切换到 Shared World 壳场景。","info"),c()}),i.querySelector("#returnHomeBase")?.addEventListener("click",async()=>{l=(await p.setScene("home-base")).world,r("已返回 Home Base。","info"),c()})}function J(){const e=i.querySelector("#assistantName");e&&(s.identity={assistantName:e.value,userName:i.querySelector("#userName").value,region:i.querySelector("#region").value,timezone:i.querySelector("#timezone").value,goal:i.querySelector("#goal").value,personality:i.querySelector("#personality").value,workStyle:i.querySelector("#workStyle").value},s.routing={...s.routing,modelRoute:i.querySelector("#modelRoute").value,tokenRule:i.querySelector("#tokenRule").value,advancedModel:i.querySelector("#advancedModel").value})}function ke(){P.innerHTML=`
    <div class="task-dock__header">
      <strong>任务派发</strong>
      <span class="muted">派发给当前龙虾，结果会回流到世界与状态镜。</span>
    </div>
    <div class="task-dock__row">
      <textarea id="taskPrompt" placeholder="例如：整理投资周报、输出部署排障清单、生成设计提案">${I}</textarea>
      <button class="action-button action-button--gold" id="dispatchTaskButton">派发</button>
    </div>
    <div class="task-dock__footer">
      <span class="muted">当前动作：${n.state} · ${n.detail}</span>
      <span class="muted">最近结果：${n.lastResult}</span>
    </div>
  `,P.querySelector("#dispatchTaskButton")?.addEventListener("click",async()=>{const e=P.querySelector("#taskPrompt").value.trim();if(I=e,!e){r("请输入任务描述。","warning");return}try{w=(await p.dispatchTask(e)).tasks,r("任务已派发，等待世界反馈。","success"),c()}catch(t){r(`派单失败: ${t.message}`,"warning")}})}function we(){const e=q(l.personaPanelStation);switch(ie.textContent=e.label,le.textContent=e.description,l.personaPanelStation){case"role-altar":ge();break;case"skill-shelf":ye();break;case"equipment-forge":G();break;case"task-desk":he();break;case"status-mirror":fe();break;case"world-portal":be();break}}function $e(){document.querySelectorAll("[data-scene]").forEach(e=>{const t=e;t.classList.toggle("is-active",t.dataset.scene===l.scene)})}function c(){ue(),me(),ve(),$e(),we(),ke(),F(),B?.setBuild(s),B?.setRuntime(n),B?.setWorld(l)}async function X(){const e=await p.build();s=e.build,L=e.roles,y={installed:e.skills.installed,reserve:e.skills.reserve,equipped:e.equipment.equipped,inventory:e.equipment.inventory}}async function Se(){await X(),n=(await p.runtime()).runtime,l=(await p.world()).world,w=(await p.tasks()).tasks;const{WorldRenderer:e}=await Z(async()=>{const{WorldRenderer:t}=await import("./world-DogaJW2i.js");return{WorldRenderer:t}},[]);B=new e(se,async t=>{l.personaPanelStation=t,c(),l=(await p.setStation(t)).world,c()}),r("World gateway 已连接。",l.connection.openclawReachable?"success":"info"),c()}document.querySelectorAll("[data-scene]").forEach(e=>{e.addEventListener("click",async()=>{const t=e.dataset.scene;l=(await p.setScene(t)).world,t==="shared-world"&&(l.personaPanelStation="world-portal"),r(t==="shared-world"?"进入 Shared World 壳场景。":"返回 Home Base。","info"),c()})});document.getElementById("saveDraftButton")?.addEventListener("click",async()=>{J();try{const e=await p.saveBuild(s);s=e.build,y={installed:e.skills.installed,reserve:e.skills.reserve,equipped:e.equipment.equipped,inventory:e.equipment.inventory},r("草稿已保存到 world gateway。","success"),c()}catch(e){r(`保存草稿失败: ${e.message}`,"warning")}});document.getElementById("applyBuildButton")?.addEventListener("click",async()=>{J();try{await p.saveBuild(s);const e=await p.applyBuild();s=e.build,y={installed:e.skills.installed,reserve:e.skills.reserve,equipped:e.equipment.equipped,inventory:e.equipment.inventory},r("构筑已应用到 OpenClaw 适配层。","success"),c()}catch(e){r(`应用失败: ${e.message}`,"warning")}});const M=new WebSocket(`${window.location.protocol==="https:"?"wss":"ws"}://${window.location.host}/ws/world`);M.addEventListener("open",()=>{r("WebSocket 已连接，实时反馈已启用。","success")});M.addEventListener("close",()=>{r("WebSocket 已断开，等待刷新重连。","warning")});M.addEventListener("message",async e=>{const t=JSON.parse(e.data);t.build&&await X(),t.runtime&&(n=t.runtime),t.tasks&&(w=t.tasks),t.world&&(l=t.world),c()});Se();export{j as H};
