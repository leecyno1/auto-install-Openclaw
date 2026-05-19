#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

# 1) Shell 语法 + 基础 lint
./scripts/lint-shell.sh || fail "shell lint"
pass "shell lint"

# 2) 行为级 smoke：安装器参数解析
bash install.sh --help >/dev/null 2>&1 || fail "install.sh --help smoke"
pass "install help smoke"

# 3) 行为级 smoke：配额核心单测 + 配置表面回归
python3 -m unittest discover -s tests -p 'test_media_quota.py' >/dev/null || fail "media quota unit tests"
pass "media quota tests"
python3 -m unittest discover -s tests -p 'test_quota_enforcer_runtime.py' >/dev/null || fail "quota enforcer runtime tests"
pass "quota enforcer runtime tests"
python3 -m unittest discover -s tests -p 'test_health_server_runtime.py' >/dev/null || fail "health server runtime tests"
pass "health server runtime tests"
python3 -m unittest discover -s tests -p 'test_pixel_house_install_smoke.py' >/dev/null || fail "pixel house install smoke tests"
pass "pixel house install smoke tests"
python3 -m unittest discover -s tests -p 'test_install_entry_smoke.py' >/dev/null || fail "install entry smoke tests"
pass "install entry smoke tests"
python3 -m unittest discover -s tests -p 'test_lobster_setup_runtime.py' >/dev/null || fail "lobster setup runtime tests"
pass "lobster setup runtime tests"
python3 -m unittest discover -s tests -p 'test_lobster_world_runtime.py' >/dev/null || fail "lobster world runtime tests"
pass "lobster world runtime tests"
python3 -m unittest discover -s tests -p 'test_config_menu_shortcuts_runtime.py' >/dev/null || fail "config menu shortcuts runtime tests"
pass "config menu shortcuts runtime tests"
python3 -m unittest discover -s tests -p 'test_config_menu_deep_runtime.py' >/dev/null || fail "config menu deep runtime tests"
pass "config menu deep runtime tests"
python3 -m unittest discover -s tests -p 'test_config_surface.py' >/dev/null || fail "config surface unit tests"
pass "config surface tests"
python3 -m unittest discover -s tests -p 'test_skills_manifest.py' >/dev/null || fail "skills manifest unit tests"
pass "skills manifest tests"
python3 -m unittest discover -s tests -p 'test_backup_manager_behavior.py' >/dev/null || fail "backup manager behavior tests"
pass "backup manager behavior tests"
python3 -m unittest discover -s tests -p 'test_launcher_contract.py' >/dev/null || fail "launcher contract tests"
pass "launcher contract tests"
python3 -m unittest discover -s tests -p 'test_readme_launcher_alignment.py' >/dev/null || fail "readme launcher alignment tests"
pass "readme launcher alignment tests"
python3 -m unittest discover -s tests -p 'test_dual_engine_smoke.py' >/dev/null || fail "dual engine smoke tests"
pass "dual engine smoke tests"

# 4) 官方升级链路关键字检查
grep -q "openclaw update --restart" config-menu.sh || fail "missing openclaw update --restart in config-menu.sh"
grep -q "openclaw plugins update --all" config-menu.sh || fail "missing plugins update --all in config-menu.sh"
pass "upgrade pipeline markers"

# 5) 飞书官方插件默认检查
grep -q 'FEISHU_PLUGIN_OFFICIAL="@openclaw/feishu"' config-menu.sh || fail "missing official feishu plugin default"
grep -q "channels.feishu.accounts.main.appId" config-menu.sh || fail "missing feishu accounts.main.appId config path"
grep -q 'install_official_plugin_local_first "$preferred_spec" "feishu"' config-menu.sh || fail "missing local-first official feishu install path"
pass "feishu plugin default marker"

# 6) 安装器官方兼容关键点
grep -q -- "--install-method, --method" install.sh || fail "install.sh missing official install-method flag"
grep -q "OFFICIAL_INSTALL_URL=\"https://openclaw.ai/install.sh\"" install.sh || fail "install.sh missing official installer url"
grep -q "MIN_NODE_MINOR=12" install.sh || fail "install.sh missing Node 22.12+ floor"
grep -q "INSTALLER_MIRROR_RAW_URL=" install.sh || fail "install.sh missing installer mirror support"
pass "installer compatibility markers"

# 7) 文档命令一致性检查
grep -q "openclaw update --restart" README.md || fail "README missing official upgrade command"
grep -q "openclaw plugins update --all" README.md || fail "README missing plugin update command"
grep -q "raw.githubusercontent.com/leecyno1/auto-install-Openclaw/main/install.sh" README.md || fail "README missing main one-click url"
grep -q "mirror.ghproxy.com/https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/main/install.sh" README.md || fail "README missing main mirror one-click url"
grep -q "openclaw-setup config" README.md || fail "README missing openclaw-setup primary entry"
pass "README command markers"

# 7b) 上市默认入口负向检查：不再推荐旧 pairing 修复或 13147 外部入口
if rg -n 'dashboard-pairing|repair-pairing|--repair-pairing' README.md install.sh config-menu.sh scripts/modules docs >/dev/null 2>&1; then
    fail "found legacy pairing repair entry references"
fi
if rg -n '外部统一入口|外部统一限流入口|13147 配额强制|限流代理自动刷新' README.md install.sh config-menu.sh scripts/modules/tier-rules.sh >/dev/null 2>&1; then
    fail "found 13147 recommended-entry wording"
fi
if rg -n 'OPENCLAW_PUBLIC_API_URL.*127\.0\.0\.1:13147|OPENCLAW_QUOTA_ENFORCER_URL.*127\.0\.0\.1:13147' README.md install.sh config-menu.sh scripts/modules/tier-rules.sh >/dev/null 2>&1; then
    fail "found default env wiring to 13147"
fi
pass "launch default negative markers"

# 8) 独立仓库命名检查（不应再指向旧仓库）
if rg -n "miaoxworld/OpenClawInstaller|raw.githubusercontent.com/miaoxworld/OpenClawInstaller" README.md install.sh config-menu.sh docs/feishu-setup.md >/dev/null 2>&1; then
    fail "found legacy upstream repository references"
fi
pass "independent repo markers"

# 9) 1:1 清单文档存在性检查
[ -f docs/official-compatibility-checklist.md ] || fail "missing official compatibility checklist doc"
pass "compatibility checklist doc"

# 10) auto-fix-openclaw + Claude/Codex 修复入口检查
grep -q 'AUTO_FIX_OPENCLAW_REPO_URL=' config-menu.sh || fail "missing auto-fix-openclaw repo variable"
grep -q 'AI 自动修复 OpenClaw' config-menu.sh || fail "missing AI auto-fix menu entry"
grep -q '执行 AI 修复（选择 Claude/Codex）' config-menu.sh || fail "missing unified AI repair entry"
grep -q 'choose_auto_fix_repair_provider' config-menu.sh || fail "missing provider chooser function"
grep -q 'check_codex_ready' config-menu.sh || fail "missing codex readiness guard"
grep -q 'codex login status' config-menu.sh || fail "missing codex login status check"
grep -q '自动读取错误日志摘要' config-menu.sh || fail "missing log-driven repair hint"
grep -q 'run_auto_fix_provider_repair codex' config-menu.sh || fail "missing codex repair entry"
grep -q 'run_auto_fix_provider_repair claudecode' config-menu.sh || fail "missing claudecode repair entry"
pass "auto-fix menu markers"

# 11) 双引擎安装与统一入口检查
grep -q -- "--engine openclaw|hermes|both" install.sh || fail "install.sh missing engine flag"
grep -q 'openclaw-setup' install.sh || fail "install.sh missing openclaw-setup entry"
grep -q 'openclaw-setup {install|config|repair|workbench|status|doctor|engine|migrate|backup|help}' install.sh || fail "install.sh missing openclaw-setup help usage"
grep -q 'install_hermes' install.sh || fail "install.sh missing Hermes install function"
grep -q 'LOBSTER_DEFAULT_ENGINE' scripts/lib/openclaw-common.sh || fail "common lib missing lobster engine state"
grep -q '引擎管理' config-menu.sh || fail "config-menu missing engine management entry"
grep -q 'openclaw_sync_dual_engine_state' scripts/lib/openclaw-common.sh || fail "common lib missing dual-engine sync helper"
grep -q 'openclaw_sync_hermes_role_profile' scripts/lib/openclaw-common.sh || fail "common lib missing Hermes role profile sync"
grep -q 'lobster-profile.env' scripts/lib/openclaw-common.sh || fail "common lib missing Hermes profile artifact"
grep -q 'sync_lobster_shared_state_install' install.sh || fail "install.sh missing shared-state sync hook"
grep -q 'sync_lobster_shared_state_menu' config-menu.sh || fail "config-menu missing shared-state sync hook"
pass "dual-engine markers"

# 12) MiniMax 官方 skills + 自定义 Provider URL 原样保存检查
BOUTIQUE_SKILLS_DIR="${OPENCLAW_SKILLS_SOURCE_DIR:-$(cd .. 2>/dev/null && pwd)/boutique-openclaw-skills/skills/default}"
for skill in \
  android-native-dev buddy-sings flutter-dev frontend-dev fullstack-dev gif-sticker-maker \
  ios-application-dev minimax-docx minimax-multimodal-toolkit minimax-music-gen \
  minimax-music-playlist minimax-pdf minimax-xlsx pptx-generator react-native-dev \
  shader-dev vision-analysis; do
    [ -f "$BOUTIQUE_SKILLS_DIR/$skill/SKILL.md" ] || fail "missing MiniMax official skill in boutique repo: $skill"
done
grep -q 'MINIMAX_OFFICIAL_SKILLS=' install.sh || fail "install.sh missing MiniMax official skill list"
grep -q 'MINIMAX_OFFICIAL_SKILLS=' config-menu.sh || fail "config-menu missing MiniMax official skill list"
grep -q '生图 API 配置（图片生成）' config-menu.sh || fail "advanced menu missing image API replacement"
normalized_url="$(bash -c 'source scripts/lib/openclaw-common.sh; openclaw_normalize_minimax_provider_url "https://api.sfkey.cn"')"
[ "$normalized_url" = "https://api.sfkey.cn" ] || fail "MiniMax custom provider URL was normalized unexpectedly: $normalized_url"
pass "MiniMax skills and raw provider URL markers"

echo "All preflight checks passed."
