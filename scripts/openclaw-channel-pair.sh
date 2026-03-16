#!/usr/bin/env bash
set -euo pipefail

CHANNEL=""
TOKEN=""
APP_ID=""
APP_SECRET=""
ENCODING_AES_KEY=""
RECEIVE_ID=""
WEBHOOK_PATH=""
ROBOT_CODE=""
ALLOW_FROM=""
GROUP_ALLOW_FROM=""
RESTART_GATEWAY=0
SKIP_DOCTOR=0

usage() {
    cat <<'EOF'
用法:
  openclaw-channel-pair --channel <qqbot|feishu|wecom|dingtalk> [参数]

通用参数:
  --channel <name>         渠道名: qqbot | feishu | wecom | dingtalk
  --token <value>          快捷凭据
  --restart                完成后重启 gateway
  --skip-doctor            跳过 openclaw doctor --fix
  -h, --help               查看帮助

渠道参数:
  QQ:
    --token "appId:appSecret"
    --allow-from "u1,u2"
  飞书:
    --token "appId:appSecret" 或单独传 --app-id/--app-secret
    --app-id <id>
    --app-secret <secret>
  企业微信(机器人模式):
    --token "<token>" 或 --token "token:encodingAESKey:receiveId"
    --aes-key <encodingAESKey>
    --receive-id <aibotid>
    --webhook-path </wecom/bot> (可选)
  钉钉:
    --token "clientId:clientSecret"
    --robot-code <code> (可选)
    --allow-from "u1,u2" (可选)
    --group-allow-from "g1,g2" (可选)
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf '⚠ %s\n' "$*" >&2; }
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

csv_to_json_array() {
    local input="${1:-}"
    local item out="[" first=1
    input="${input// /}"
    IFS=',' read -r -a arr <<< "$input"
    for item in "${arr[@]}"; do
        [ -n "$item" ] || continue
        if [ "$first" -eq 1 ]; then
            out="${out}\"${item}\""
            first=0
        else
            out="${out},\"${item}\""
        fi
    done
    out="${out}]"
    echo "$out"
}

pair_split_2() {
    local raw="$1"
    [[ "$raw" == *:* ]] || return 1
    printf '%s\n' "${raw%%:*}"
    printf '%s\n' "${raw#*:}"
}

pair_split_3() {
    local raw="$1"
    local a b c rest
    [[ "$raw" == *:*:* ]] || return 1
    a="${raw%%:*}"
    rest="${raw#*:}"
    b="${rest%%:*}"
    c="${rest#*:}"
    printf '%s\n' "$a"
    printf '%s\n' "$b"
    printf '%s\n' "$c"
}

ensure_openclaw() {
    command -v openclaw >/dev/null 2>&1 || die "未找到 openclaw，请先安装 OpenClaw"
}

try_enable_plugin() {
    local id="$1"
    openclaw plugins enable "$id" >/dev/null 2>&1 || true
}

setup_common() {
    case "$CHANNEL" in
        qqbot) try_enable_plugin "qqbot" ;;
        feishu) try_enable_plugin "feishu" ;;
        wecom)
            try_enable_plugin "wecom-openclaw-plugin"
            try_enable_plugin "wecom"
            ;;
        dingtalk) try_enable_plugin "dingtalk" ;;
    esac
}

configure_qqbot() {
    local app_id app_secret
    [ -n "$TOKEN" ] || die "QQ 需要 --token \"appId:appSecret\""
    mapfile -t pair < <(pair_split_2 "$TOKEN") || die "QQ token 格式错误，应为 appId:appSecret"
    app_id="${pair[0]}"
    app_secret="${pair[1]}"
    [ -n "$app_id" ] && [ -n "$app_secret" ] || die "QQ appId/appSecret 不能为空"

    openclaw config set channels.qqbot.enabled true >/dev/null 2>&1 || true
    openclaw config set channels.qqbot.defaultAccount main >/dev/null 2>&1 || true
    openclaw config set channels.qqbot.accounts.main.enabled true >/dev/null 2>&1 || true
    openclaw config set channels.qqbot.accounts.main.appId "$app_id" >/dev/null 2>&1 || true
    openclaw config set channels.qqbot.accounts.main.appSecret "$app_secret" >/dev/null 2>&1 || true
    if [ -n "$ALLOW_FROM" ]; then
        local allow_json
        allow_json="$(csv_to_json_array "$ALLOW_FROM")"
        openclaw config set channels.qqbot.allowFrom "$allow_json" >/dev/null 2>&1 || true
        openclaw config set channels.qqbot.accounts.main.allowFrom "$allow_json" >/dev/null 2>&1 || true
    fi

    openclaw channels add --channel qqbot --token "$TOKEN" >/dev/null 2>&1 || true
    log "✓ QQ 配置完成"
}

configure_feishu() {
    local app_id="$APP_ID" app_secret="$APP_SECRET"
    if [ -z "$app_id" ] || [ -z "$app_secret" ]; then
        [ -n "$TOKEN" ] || die "飞书需要 --token \"appId:appSecret\" 或 --app-id/--app-secret"
        mapfile -t pair < <(pair_split_2 "$TOKEN") || die "飞书 token 格式错误，应为 appId:appSecret"
        app_id="${pair[0]}"
        app_secret="${pair[1]}"
    fi
    [ -n "$app_id" ] && [ -n "$app_secret" ] || die "飞书 appId/appSecret 不能为空"

    openclaw config set channels.feishu.enabled true >/dev/null 2>&1 || true
    openclaw config set channels.feishu.defaultAccount main >/dev/null 2>&1 || true
    openclaw config set channels.feishu.accounts.main.enabled true >/dev/null 2>&1 || true
    openclaw config set channels.feishu.accounts.main.appId "$app_id" >/dev/null 2>&1 || true
    openclaw config set channels.feishu.accounts.main.appSecret "$app_secret" >/dev/null 2>&1 || true
    openclaw channels add --channel feishu >/dev/null 2>&1 || true
    log "✓ 飞书配置完成"
}

configure_wecom() {
    local token="$TOKEN" aes="$ENCODING_AES_KEY" rid="$RECEIVE_ID"
    if [ -n "$token" ] && [ -z "$aes" ] && [ -z "$rid" ] && [[ "$token" == *:*:* ]]; then
        mapfile -t triplet < <(pair_split_3 "$token")
        token="${triplet[0]}"
        aes="${triplet[1]}"
        rid="${triplet[2]}"
    fi
    [ -n "$token" ] || die "企业微信需要 --token"
    [ -n "$aes" ] || die "企业微信需要 --aes-key（或使用 token:aes:receiveId）"
    [ -n "$rid" ] || die "企业微信需要 --receive-id（或使用 token:aes:receiveId）"
    [ -n "$WEBHOOK_PATH" ] || WEBHOOK_PATH="/wecom/bot"

    openclaw config set channels.wecom.enabled true >/dev/null 2>&1 || true
    openclaw config set channels.wecom.mode bot >/dev/null 2>&1 || true
    openclaw config set channels.wecom.defaultAccount bot >/dev/null 2>&1 || true
    openclaw config set channels.wecom.accounts.bot.mode bot >/dev/null 2>&1 || true
    openclaw config set channels.wecom.accounts.bot.webhookPath "$WEBHOOK_PATH" >/dev/null 2>&1 || true
    openclaw config set channels.wecom.accounts.bot.token "$token" >/dev/null 2>&1 || true
    openclaw config set channels.wecom.accounts.bot.encodingAESKey "$aes" >/dev/null 2>&1 || true
    openclaw config set channels.wecom.accounts.bot.receiveId "$rid" >/dev/null 2>&1 || true
    openclaw config unset channels.wecom.accounts.app >/dev/null 2>&1 || true

    # 该插件当前不一定支持 channels add，失败可忽略
    openclaw channels add --channel wecom >/dev/null 2>&1 || true
    log "✓ 企业微信配置完成（机器人模式）"
}

configure_dingtalk() {
    local client_id client_secret
    [ -n "$TOKEN" ] || die "钉钉需要 --token \"clientId:clientSecret\""
    mapfile -t pair < <(pair_split_2 "$TOKEN") || die "钉钉 token 格式错误，应为 clientId:clientSecret"
    client_id="${pair[0]}"
    client_secret="${pair[1]}"
    [ -n "$client_id" ] && [ -n "$client_secret" ] || die "钉钉 clientId/clientSecret 不能为空"

    openclaw config set channels.dingtalk.enabled true >/dev/null 2>&1 || true
    openclaw config set channels.dingtalk.accounts.main.enabled true >/dev/null 2>&1 || true
    openclaw config set channels.dingtalk.accounts.main.clientId "$client_id" >/dev/null 2>&1 || true
    openclaw config set channels.dingtalk.accounts.main.clientSecret "$client_secret" >/dev/null 2>&1 || true
    openclaw config set channels.dingtalk.clientId "$client_id" >/dev/null 2>&1 || true
    openclaw config set channels.dingtalk.clientSecret "$client_secret" >/dev/null 2>&1 || true
    if [ -n "$ROBOT_CODE" ]; then
        openclaw config set channels.dingtalk.accounts.main.robotCode "$ROBOT_CODE" >/dev/null 2>&1 || true
        openclaw config set channels.dingtalk.robotCode "$ROBOT_CODE" >/dev/null 2>&1 || true
    fi
    if [ -n "$ALLOW_FROM" ]; then
        local allow_json
        allow_json="$(csv_to_json_array "$ALLOW_FROM")"
        openclaw config set channels.dingtalk.accounts.main.allowFrom "$allow_json" >/dev/null 2>&1 || true
    fi
    if [ -n "$GROUP_ALLOW_FROM" ]; then
        local group_json
        group_json="$(csv_to_json_array "$GROUP_ALLOW_FROM")"
        openclaw config set channels.dingtalk.accounts.main.groupAllowFrom "$group_json" >/dev/null 2>&1 || true
    fi

    # 该插件当前不一定支持 channels add，失败可忽略
    openclaw channels add --channel dingtalk >/dev/null 2>&1 || true
    log "✓ 钉钉配置完成"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --channel) CHANNEL="${2:-}"; shift 2 ;;
        --token) TOKEN="${2:-}"; shift 2 ;;
        --app-id) APP_ID="${2:-}"; shift 2 ;;
        --app-secret) APP_SECRET="${2:-}"; shift 2 ;;
        --aes-key) ENCODING_AES_KEY="${2:-}"; shift 2 ;;
        --receive-id) RECEIVE_ID="${2:-}"; shift 2 ;;
        --webhook-path) WEBHOOK_PATH="${2:-}"; shift 2 ;;
        --robot-code) ROBOT_CODE="${2:-}"; shift 2 ;;
        --allow-from) ALLOW_FROM="${2:-}"; shift 2 ;;
        --group-allow-from) GROUP_ALLOW_FROM="${2:-}"; shift 2 ;;
        --restart) RESTART_GATEWAY=1; shift ;;
        --skip-doctor) SKIP_DOCTOR=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "未知参数: $1（使用 --help 查看帮助）" ;;
    esac
done

ensure_openclaw
[ -n "$CHANNEL" ] || die "请传入 --channel"

setup_common
case "$CHANNEL" in
    qqbot) configure_qqbot ;;
    feishu) configure_feishu ;;
    wecom) configure_wecom ;;
    dingtalk) configure_dingtalk ;;
    *) die "不支持的渠道: $CHANNEL（仅支持 qqbot/feishu/wecom/dingtalk）" ;;
esac

if [ "$SKIP_DOCTOR" -ne 1 ]; then
    openclaw doctor --fix >/dev/null 2>&1 || warn "doctor --fix 执行失败，请手动排查"
fi

if [ "$RESTART_GATEWAY" -eq 1 ]; then
    openclaw gateway restart >/dev/null 2>&1 || warn "gateway 重启失败，请手动执行 openclaw gateway restart"
fi

log ""
log "已完成 $CHANNEL 配置。建议检查：openclaw channels list"

