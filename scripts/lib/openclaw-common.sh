#!/usr/bin/env bash

# Shared helper functions for installer/config scripts.

openclaw_trim_value() {
    printf "%s" "${1:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

openclaw_normalize_minimax_provider_url() {
    local raw
    raw="$(openclaw_trim_value "${1:-}")"
    [ -n "$raw" ] || { echo ""; return 0; }
    # Intentionally do not append /anthropic.
    echo "$raw"
}

openclaw_minimax_api_host_from_provider_url() {
    local provider_url
    provider_url="$(openclaw_normalize_minimax_provider_url "${1:-}")"
    [ -n "$provider_url" ] || { echo ""; return 0; }
    echo "$provider_url"
}

openclaw_resolve_minimax_provider_base_url() {
    local provider="${1:-}"
    local custom_provider_url="${2:-}"
    local default_base_url="https://api.minimax.io/anthropic"

    if [ "$provider" = "minimax-cn" ]; then
        default_base_url="https://api.minimaxi.com/anthropic"
    fi

    local normalized_custom
    normalized_custom="$(openclaw_normalize_minimax_provider_url "$custom_provider_url")"
    if [ -n "$normalized_custom" ]; then
        echo "$normalized_custom"
    else
        echo "$default_base_url"
    fi
}

openclaw_normalize_rule_profile_level() {
    local default_level="${2:-medium}"
    local level
    level="$(printf "%s" "${1:-$default_level}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

    case "$level" in
        low|medium|high|none) echo "$level" ;;
        l) echo "low" ;;
        m|mid) echo "medium" ;;
        h) echo "high" ;;
        n|no|skip|off) echo "none" ;;
        *) echo "medium" ;;
    esac
}

openclaw_split_api_url() {
    local raw="${1:-}"
    local default_endpoint="${2:-/v1/chat/completions}"
    local base_url="" endpoint="" host_part=""

    raw="$(openclaw_trim_value "$raw")"
    [ -n "$raw" ] || { echo "|$default_endpoint"; return 0; }

    if [[ "$raw" == http://* || "$raw" == https://* ]]; then
        host_part="$(echo "$raw" | sed -E 's#^(https?://[^/]+).*$#\1#')"
        endpoint="${raw#"$host_part"}"
        [ -n "$endpoint" ] || endpoint="$default_endpoint"
        base_url="$host_part"
    else
        base_url="$raw"
        endpoint="$default_endpoint"
    fi

    echo "${base_url}|${endpoint}"
}

openclaw_lobster_home() {
    echo "${LOBSTER_HOME:-$HOME/.lobster}"
}

openclaw_lobster_config_dir() {
    echo "$(openclaw_lobster_home)/config"
}

openclaw_lobster_engine_env_path() {
    echo "$(openclaw_lobster_config_dir)/engine.env"
}

openclaw_normalize_engine_id() {
    local raw
    raw="$(printf "%s" "${1:-openclaw}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$raw" in
        openclaw|claw|open-cloud|opencloud) echo "openclaw" ;;
        hermes|hermes-agent) echo "hermes" ;;
        both|all|openclaw,hermes|hermes,openclaw|dual) echo "both" ;;
        *) echo "openclaw" ;;
    esac
}

openclaw_engine_includes() {
    local engine target
    engine="$(openclaw_normalize_engine_id "${1:-openclaw}")"
    target="$(openclaw_normalize_engine_id "${2:-openclaw}")"
    [ "$engine" = "both" ] || [ "$engine" = "$target" ]
}

openclaw_engine_installed_csv() {
    local engine
    engine="$(openclaw_normalize_engine_id "${1:-openclaw}")"
    case "$engine" in
        both) echo "openclaw,hermes" ;;
        hermes) echo "hermes" ;;
        *) echo "openclaw" ;;
    esac
}

openclaw_get_lobster_config_value() {
    local key="$1"
    local default_value="${2:-}"
    local file
    file="$(openclaw_lobster_engine_env_path)"

    if [ -f "$file" ]; then
        local value
        value="$(grep -E "^${key}=" "$file" 2>/dev/null | tail -1 | sed -E "s/^${key}=//; s/^\"//; s/\"$//")"
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    fi
    echo "$default_value"
}

openclaw_get_lobster_default_engine() {
    openclaw_normalize_engine_id "$(openclaw_get_lobster_config_value LOBSTER_DEFAULT_ENGINE openclaw)"
}

openclaw_get_lobster_installed_engines() {
    openclaw_get_lobster_config_value LOBSTER_INSTALLED_ENGINES openclaw
}

openclaw_set_lobster_engine_state() {
    local default_engine installed_engines config_dir config_file tmp_file
    default_engine="$(openclaw_normalize_engine_id "${1:-openclaw}")"
    if [ "$default_engine" = "both" ]; then
        default_engine="openclaw"
    fi
    installed_engines="${2:-$(openclaw_engine_installed_csv "$default_engine")}"
    config_dir="$(openclaw_lobster_config_dir)"
    config_file="$(openclaw_lobster_engine_env_path)"

    mkdir -p "$config_dir" 2>/dev/null || return 1
    tmp_file="$(mktemp)"
    {
        echo "LOBSTER_DEFAULT_ENGINE=\"${default_engine}\""
        echo "LOBSTER_INSTALLED_ENGINES=\"${installed_engines}\""
        echo "LOBSTER_OPENCLAW_HOME=\"${OPENCLAW_HOME:-$HOME/.openclaw}\""
        echo "LOBSTER_HERMES_HOME=\"${HERMES_HOME:-$HOME/.hermes}\""
        echo "LOBSTER_PIXEL_HOUSE_ENGINE=\"openclaw\""
    } > "$tmp_file"
    mv "$tmp_file" "$config_file"
    chmod 600 "$config_file" 2>/dev/null || true
}

openclaw_lobster_shared_env_path() {
    echo "$(openclaw_lobster_config_dir)/shared.env"
}

openclaw_hermes_env_path() {
    local hermes_home="${1:-${HERMES_HOME:-$HOME/.hermes}}"
    echo "${hermes_home}/.env"
}

openclaw_escape_env_value() {
    printf "%s" "${1:-}" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

openclaw_read_shell_kv_value() {
    local key="$1"
    local file="$2"
    [ -f "$file" ] || return 0
    grep -E "^(export[[:space:]]+)?${key}=" "$file" 2>/dev/null | tail -1 | sed -E "s/^(export[[:space:]]+)?${key}=//; s/^\"//; s/\"$//" || true
}

openclaw_resolve_value_from_env_or_file() {
    local key="$1"
    local file="${2:-}"
    local value="${!key:-}"
    if [ -n "$value" ]; then
        printf "%s" "$value"
        return 0
    fi
    if [ -n "$file" ]; then
        openclaw_read_shell_kv_value "$key" "$file"
    fi
}

openclaw_sync_lobster_shared_env() {
    local source_env="${1:-$HOME/.openclaw/env}"
    local output_file="${2:-$(openclaw_lobster_shared_env_path)}"
    local config_dir
    config_dir="$(dirname "$output_file")"
    mkdir -p "$config_dir" 2>/dev/null || return 1

    local default_engine installed_engines
    default_engine="$(openclaw_get_lobster_default_engine)"
    installed_engines="$(openclaw_get_lobster_installed_engines)"

    local keys=(
        OPENCLAW_PERSONA_ROLE
        OPENCLAW_ASSISTANT_NAME
        OPENCLAW_ASSISTANT_EMOJI
        OPENCLAW_USER_NAME
        OPENCLAW_REGION
        OPENCLAW_TIMEZONE
        OPENCLAW_WELCOME_MESSAGE
        OPENCLAW_USER_GOAL
        OPENCLAW_ASSISTANT_PERSONALITY
        OPENCLAW_ASSISTANT_WORK_MODE
        OPENCLAW_ASSISTANT_WORK_STYLE
        OPENCLAW_ROLE_CORE_SKILLS
        OPENCLAW_ROLE_EXTRA_SKILLS
        OPENCLAW_RULE_PROFILE
        OPENCLAW_WEB_SKILL_PACK
        OPENCLAW_PROFILE_SKILL_PACK_LABEL
        OPENCLAW_PROFILE_SKILL_LIST
        OPENCLAW_PROFILE_SKILL_COUNT
        OPENCLAW_ACTIVE_PROVIDER_PRESET
        OPENCLAW_ACTIVE_PROVIDER_MODEL
        OPENCLAW_ACTIVE_PROVIDER_BASE_URL
        OPENCLAW_ACTIVE_PROVIDER_API_TYPE
        OPENCLAW_CUSTOM_PROVIDER_ID
        OPENCLAW_CUSTOM_PROVIDER_NAME
        OPENCLAW_CUSTOM_PROVIDER_BASE_URL
        OPENCLAW_CUSTOM_PROVIDER_MODEL
        OPENCLAW_CUSTOM_PROVIDER_API_TYPE
        OPENCLAW_CUSTOM_PROVIDER_API_KEY
        OPENCLAW_WEB_MODEL_ROUTE
        OPENCLAW_WEB_TOOLS
        OPENCLAW_WEB_SECURITY
        OPENCLAW_RULE_WINDOW_HOURS
        OPENCLAW_RULE_MAX_REQUESTS
        OPENCLAW_RULE_MAX_TOKENS
        OPENCLAW_RULE_MAX_TOKENS_PER_REQUEST
        OPENCLAW_RULE_MAX_IMAGE_REQUESTS
        OPENCLAW_RULE_MAX_VIDEO_REQUESTS
        OPENCLAW_CONTEXT_WARN_TOKENS
        OPENCLAW_CONTEXT_ASK_TOKENS
        OPENCLAW_CONTEXT_FORCE_TOKENS
        OPENCLAW_CONTEXT_ASK_COMMAND
        OPENCLAW_IMAGE_PROVIDER_ID
        OPENCLAW_IMAGE_PROVIDER_NAME
        OPENCLAW_IMAGE_API_KEY
        OPENCLAW_IMAGE_API_URL
        OPENCLAW_IMAGE_MODEL
        OPENCLAW_RULE_ADVANCED_MODEL_API_URL
        OPENCLAW_RULE_ADVANCED_MODEL_NAME
        OPENCLAW_RULE_ADVANCED_MODEL_API_KEY
        OPENCLAW_BM_COMMAND
        OPENAI_API_KEY
        OPENAI_BASE_URL
        ANTHROPIC_API_KEY
        ANTHROPIC_BASE_URL
        OPENROUTER_API_KEY
        OPENROUTER_BASE_URL
        GOOGLE_API_KEY
        GEMINI_API_KEY
        GEMINI_BASE_URL
        MINIMAX_API_KEY
        MINIMAX_BASE_URL
        MINIMAX_API_HOST
        MINIMAX_MULTIMODAL_OUTPUT_PATH
        MINIMAX_MCP_BASE_PATH
        MINIMAX_API_RESOURCE_MODE
        MINIMAX_IMAGE_MODEL
        MINIMAX_IMAGE_ENDPOINT
        MINIMAX_TTS_MODEL
        MINIMAX_TTS_ENDPOINT
        MINIMAX_VIDEO_MODEL
        MINIMAX_VIDEO_ENDPOINT
        MINIMAX_VIDEO_QUERY_ENDPOINT
        MINIMAX_FILES_RETRIEVE_ENDPOINT
        MINIMAX_MUSIC_MODEL
        MINIMAX_MUSIC_ENDPOINT
        OPENCLAW_MINIMAX_PROVIDER_URL
        DEEPSEEK_API_KEY
        DEEPSEEK_BASE_URL
        MOONSHOT_API_KEY
        MOONSHOT_BASE_URL
        MISTRAL_API_KEY
        MISTRAL_BASE_URL
        GROQ_API_KEY
        GROQ_BASE_URL
        XAI_API_KEY
        ZAI_API_KEY
        OPENCODE_API_KEY
        EXA_API_KEY
        PARALLEL_API_KEY
        FIRECRAWL_API_KEY
        FAL_KEY
    )

    local tmp_file key value escaped
    tmp_file="$(mktemp)"
    {
        echo "LOBSTER_DEFAULT_ENGINE=\"$(openclaw_escape_env_value "$default_engine")\""
        echo "LOBSTER_INSTALLED_ENGINES=\"$(openclaw_escape_env_value "$installed_engines")\""
        echo "LOBSTER_OPENCLAW_HOME=\"$(openclaw_escape_env_value "${OPENCLAW_HOME:-$HOME/.openclaw}")\""
        echo "LOBSTER_HERMES_HOME=\"$(openclaw_escape_env_value "${HERMES_HOME:-$HOME/.hermes}")\""
        echo "LOBSTER_PIXEL_HOUSE_ENGINE=\"openclaw\""
        for key in "${keys[@]}"; do
            value="$(openclaw_resolve_value_from_env_or_file "$key" "$source_env")"
            if [ -n "$value" ]; then
                escaped="$(openclaw_escape_env_value "$value")"
                echo "${key}=\"${escaped}\""
            fi
        done
    } > "$tmp_file"
    mv "$tmp_file" "$output_file"
    chmod 600 "$output_file" 2>/dev/null || true
}

openclaw_sync_hermes_env_from_shared() {
    local shared_env="${1:-$(openclaw_lobster_shared_env_path)}"
    local hermes_home="${2:-${HERMES_HOME:-$HOME/.hermes}}"
    local output_file
    output_file="$(openclaw_hermes_env_path "$hermes_home")"
    mkdir -p "$hermes_home" 2>/dev/null || return 1

    local tmp_file
    tmp_file="$(mktemp)"

    local write_var
    write_var() {
        local key="$1"
        local value="$2"
        [ -n "$value" ] || return 0
        echo "${key}=\"$(openclaw_escape_env_value "$value")\"" >> "$tmp_file"
    }

    local get_shared
    get_shared() {
        openclaw_read_shell_kv_value "$1" "$shared_env"
    }

    {
        echo "# Generated by Lobster shared control layer"
        echo "# Do not edit manually unless you know the sync flow."
    } > "$tmp_file"

    write_var "LOBSTER_DEFAULT_ENGINE" "$(get_shared LOBSTER_DEFAULT_ENGINE)"
    write_var "LOBSTER_INSTALLED_ENGINES" "$(get_shared LOBSTER_INSTALLED_ENGINES)"
    write_var "LOBSTER_PERSONA_ROLE" "$(get_shared OPENCLAW_PERSONA_ROLE)"
    write_var "LOBSTER_ASSISTANT_NAME" "$(get_shared OPENCLAW_ASSISTANT_NAME)"
    write_var "LOBSTER_USER_GOAL" "$(get_shared OPENCLAW_USER_GOAL)"
    write_var "LOBSTER_ASSISTANT_PERSONALITY" "$(get_shared OPENCLAW_ASSISTANT_PERSONALITY)"
    write_var "LOBSTER_ASSISTANT_WORK_MODE" "$(get_shared OPENCLAW_ASSISTANT_WORK_MODE)"
    write_var "LOBSTER_RULE_PROFILE" "$(get_shared OPENCLAW_RULE_PROFILE)"
    write_var "LOBSTER_SKILL_PACK" "$(get_shared OPENCLAW_WEB_SKILL_PACK)"
    write_var "LOBSTER_SKILL_PACK_LABEL" "$(get_shared OPENCLAW_PROFILE_SKILL_PACK_LABEL)"
    write_var "LOBSTER_PROFILE_SKILL_LIST" "$(get_shared OPENCLAW_PROFILE_SKILL_LIST)"
    write_var "LOBSTER_PROFILE_SKILL_COUNT" "$(get_shared OPENCLAW_PROFILE_SKILL_COUNT)"
    write_var "LOBSTER_MODEL_ROUTE" "$(get_shared OPENCLAW_WEB_MODEL_ROUTE)"
    write_var "LOBSTER_RULE_WINDOW_HOURS" "$(get_shared OPENCLAW_RULE_WINDOW_HOURS)"
    write_var "LOBSTER_RULE_MAX_REQUESTS" "$(get_shared OPENCLAW_RULE_MAX_REQUESTS)"
    write_var "LOBSTER_RULE_MAX_TOKENS" "$(get_shared OPENCLAW_RULE_MAX_TOKENS)"
    write_var "LOBSTER_RULE_MAX_TOKENS_PER_REQUEST" "$(get_shared OPENCLAW_RULE_MAX_TOKENS_PER_REQUEST)"
    write_var "LOBSTER_RULE_MAX_IMAGE_REQUESTS" "$(get_shared OPENCLAW_RULE_MAX_IMAGE_REQUESTS)"
    write_var "LOBSTER_RULE_MAX_VIDEO_REQUESTS" "$(get_shared OPENCLAW_RULE_MAX_VIDEO_REQUESTS)"
    write_var "LOBSTER_CONTEXT_WARN_TOKENS" "$(get_shared OPENCLAW_CONTEXT_WARN_TOKENS)"
    write_var "LOBSTER_CONTEXT_ASK_TOKENS" "$(get_shared OPENCLAW_CONTEXT_ASK_TOKENS)"
    write_var "LOBSTER_CONTEXT_FORCE_TOKENS" "$(get_shared OPENCLAW_CONTEXT_FORCE_TOKENS)"
    write_var "LOBSTER_CONTEXT_ASK_COMMAND" "$(get_shared OPENCLAW_CONTEXT_ASK_COMMAND)"
    write_var "LOBSTER_ACTIVE_PROVIDER_PRESET" "$(get_shared OPENCLAW_ACTIVE_PROVIDER_PRESET)"
    write_var "LOBSTER_ACTIVE_PROVIDER_MODEL" "$(get_shared OPENCLAW_ACTIVE_PROVIDER_MODEL)"
    write_var "LOBSTER_ACTIVE_PROVIDER_BASE_URL" "$(get_shared OPENCLAW_ACTIVE_PROVIDER_BASE_URL)"
    write_var "LOBSTER_ACTIVE_PROVIDER_API_TYPE" "$(get_shared OPENCLAW_ACTIVE_PROVIDER_API_TYPE)"
    write_var "LOBSTER_IMAGE_API_URL" "$(get_shared OPENCLAW_IMAGE_API_URL)"
    write_var "LOBSTER_IMAGE_MODEL" "$(get_shared OPENCLAW_IMAGE_MODEL)"
    write_var "LOBSTER_BM_COMMAND" "$(get_shared OPENCLAW_BM_COMMAND)"
    write_var "OPENCLAW_ACTIVE_PROVIDER_PRESET" "$(get_shared OPENCLAW_ACTIVE_PROVIDER_PRESET)"
    write_var "OPENCLAW_ACTIVE_PROVIDER_MODEL" "$(get_shared OPENCLAW_ACTIVE_PROVIDER_MODEL)"
    write_var "OPENCLAW_ACTIVE_PROVIDER_BASE_URL" "$(get_shared OPENCLAW_ACTIVE_PROVIDER_BASE_URL)"
    write_var "OPENCLAW_ACTIVE_PROVIDER_API_TYPE" "$(get_shared OPENCLAW_ACTIVE_PROVIDER_API_TYPE)"
    write_var "OPENCLAW_CUSTOM_PROVIDER_ID" "$(get_shared OPENCLAW_CUSTOM_PROVIDER_ID)"
    write_var "OPENCLAW_CUSTOM_PROVIDER_NAME" "$(get_shared OPENCLAW_CUSTOM_PROVIDER_NAME)"
    write_var "OPENCLAW_CUSTOM_PROVIDER_BASE_URL" "$(get_shared OPENCLAW_CUSTOM_PROVIDER_BASE_URL)"
    write_var "OPENCLAW_CUSTOM_PROVIDER_MODEL" "$(get_shared OPENCLAW_CUSTOM_PROVIDER_MODEL)"
    write_var "OPENCLAW_CUSTOM_PROVIDER_API_TYPE" "$(get_shared OPENCLAW_CUSTOM_PROVIDER_API_TYPE)"
    write_var "OPENCLAW_CUSTOM_PROVIDER_API_KEY" "$(get_shared OPENCLAW_CUSTOM_PROVIDER_API_KEY)"
    write_var "OPENCLAW_IMAGE_PROVIDER_ID" "$(get_shared OPENCLAW_IMAGE_PROVIDER_ID)"
    write_var "OPENCLAW_IMAGE_PROVIDER_NAME" "$(get_shared OPENCLAW_IMAGE_PROVIDER_NAME)"
    write_var "OPENCLAW_IMAGE_API_KEY" "$(get_shared OPENCLAW_IMAGE_API_KEY)"
    write_var "OPENCLAW_IMAGE_API_URL" "$(get_shared OPENCLAW_IMAGE_API_URL)"
    write_var "OPENCLAW_IMAGE_MODEL" "$(get_shared OPENCLAW_IMAGE_MODEL)"

    write_var "OPENAI_API_KEY" "$(get_shared OPENAI_API_KEY)"
    write_var "OPENAI_BASE_URL" "$(get_shared OPENAI_BASE_URL)"
    write_var "ANTHROPIC_API_KEY" "$(get_shared ANTHROPIC_API_KEY)"
    write_var "ANTHROPIC_BASE_URL" "$(get_shared ANTHROPIC_BASE_URL)"
    write_var "OPENROUTER_API_KEY" "$(get_shared OPENROUTER_API_KEY)"
    write_var "OPENROUTER_BASE_URL" "$(get_shared OPENROUTER_BASE_URL)"

    local google_key gemini_key gemini_base
    google_key="$(get_shared GOOGLE_API_KEY)"
    gemini_key="$(get_shared GEMINI_API_KEY)"
    gemini_base="$(get_shared GEMINI_BASE_URL)"
    [ -z "$google_key" ] && google_key="$gemini_key"
    [ -z "$gemini_key" ] && gemini_key="$google_key"
    write_var "GOOGLE_API_KEY" "$google_key"
    write_var "GEMINI_API_KEY" "$gemini_key"
    write_var "GEMINI_BASE_URL" "$gemini_base"

    local minimax_base
    minimax_base="$(get_shared MINIMAX_BASE_URL)"
    [ -z "$minimax_base" ] && minimax_base="$(get_shared OPENCLAW_MINIMAX_PROVIDER_URL)"
    write_var "MINIMAX_API_KEY" "$(get_shared MINIMAX_API_KEY)"
    write_var "MINIMAX_BASE_URL" "$minimax_base"
    write_var "MINIMAX_API_HOST" "$(get_shared MINIMAX_API_HOST)"
    write_var "MINIMAX_MULTIMODAL_OUTPUT_PATH" "$(get_shared MINIMAX_MULTIMODAL_OUTPUT_PATH)"
    write_var "MINIMAX_MCP_BASE_PATH" "$(get_shared MINIMAX_MCP_BASE_PATH)"
    write_var "MINIMAX_API_RESOURCE_MODE" "$(get_shared MINIMAX_API_RESOURCE_MODE)"
    write_var "MINIMAX_IMAGE_MODEL" "$(get_shared MINIMAX_IMAGE_MODEL)"
    write_var "MINIMAX_IMAGE_ENDPOINT" "$(get_shared MINIMAX_IMAGE_ENDPOINT)"
    write_var "MINIMAX_TTS_MODEL" "$(get_shared MINIMAX_TTS_MODEL)"
    write_var "MINIMAX_TTS_ENDPOINT" "$(get_shared MINIMAX_TTS_ENDPOINT)"
    write_var "MINIMAX_VIDEO_MODEL" "$(get_shared MINIMAX_VIDEO_MODEL)"
    write_var "MINIMAX_VIDEO_ENDPOINT" "$(get_shared MINIMAX_VIDEO_ENDPOINT)"
    write_var "MINIMAX_VIDEO_QUERY_ENDPOINT" "$(get_shared MINIMAX_VIDEO_QUERY_ENDPOINT)"
    write_var "MINIMAX_FILES_RETRIEVE_ENDPOINT" "$(get_shared MINIMAX_FILES_RETRIEVE_ENDPOINT)"
    write_var "MINIMAX_MUSIC_MODEL" "$(get_shared MINIMAX_MUSIC_MODEL)"
    write_var "MINIMAX_MUSIC_ENDPOINT" "$(get_shared MINIMAX_MUSIC_ENDPOINT)"
    write_var "OPENCLAW_MINIMAX_PROVIDER_URL" "$(get_shared OPENCLAW_MINIMAX_PROVIDER_URL)"
    write_var "DEEPSEEK_API_KEY" "$(get_shared DEEPSEEK_API_KEY)"
    write_var "DEEPSEEK_BASE_URL" "$(get_shared DEEPSEEK_BASE_URL)"
    write_var "MOONSHOT_API_KEY" "$(get_shared MOONSHOT_API_KEY)"
    write_var "MOONSHOT_BASE_URL" "$(get_shared MOONSHOT_BASE_URL)"
    write_var "MISTRAL_API_KEY" "$(get_shared MISTRAL_API_KEY)"
    write_var "MISTRAL_BASE_URL" "$(get_shared MISTRAL_BASE_URL)"
    write_var "GROQ_API_KEY" "$(get_shared GROQ_API_KEY)"
    write_var "GROQ_BASE_URL" "$(get_shared GROQ_BASE_URL)"
    write_var "XAI_API_KEY" "$(get_shared XAI_API_KEY)"
    write_var "ZAI_API_KEY" "$(get_shared ZAI_API_KEY)"
    write_var "OPENCODE_API_KEY" "$(get_shared OPENCODE_API_KEY)"

    write_var "EXA_API_KEY" "$(get_shared EXA_API_KEY)"
    write_var "PARALLEL_API_KEY" "$(get_shared PARALLEL_API_KEY)"
    write_var "FIRECRAWL_API_KEY" "$(get_shared FIRECRAWL_API_KEY)"
    write_var "FAL_KEY" "$(get_shared FAL_KEY)"

    mv "$tmp_file" "$output_file"
    chmod 600 "$output_file" 2>/dev/null || true
}

openclaw_sync_hermes_skill_links() {
    local openclaw_home="${1:-${OPENCLAW_HOME:-$HOME/.openclaw}}"
    local hermes_home="${2:-${HERMES_HOME:-$HOME/.hermes}}"
    local src_root dst_root src dst name current_target

    src_root="${openclaw_home}/skills"
    dst_root="$(openclaw_hermes_skills_dir "$hermes_home")"
    [ -d "$src_root" ] || return 0
    mkdir -p "$dst_root" 2>/dev/null || return 1

    for src in "$src_root"/*; do
        [ -d "$src" ] || continue
        [ -f "$src/SKILL.md" ] || continue
        name="$(basename "$src")"
        dst="${dst_root}/${name}"

        if [ -L "$dst" ]; then
            current_target="$(readlink "$dst" 2>/dev/null || true)"
            if [ "$current_target" = "$src" ]; then
                continue
            fi
            rm -f "$dst" 2>/dev/null || true
        elif [ -e "$dst" ]; then
            continue
        fi

        ln -s "$src" "$dst" 2>/dev/null || true
    done

    for dst in "$dst_root"/*; do
        [ -L "$dst" ] || continue
        src="$(readlink "$dst" 2>/dev/null || true)"
        case "$src" in
            "${src_root}"/*)
                [ -e "$src" ] || rm -f "$dst" 2>/dev/null || true
                ;;
        esac
    done
}

openclaw_sync_dual_engine_state() {
    local source_env="${1:-$HOME/.openclaw/env}"
    local hermes_home="${2:-${HERMES_HOME:-$HOME/.hermes}}"
    openclaw_sync_lobster_shared_env "$source_env" "$(openclaw_lobster_shared_env_path)"
    openclaw_sync_hermes_env_from_shared "$(openclaw_lobster_shared_env_path)" "$hermes_home"
    openclaw_sync_hermes_role_profile "$(openclaw_lobster_shared_env_path)" "$hermes_home"
    openclaw_sync_hermes_skill_links "${OPENCLAW_HOME:-$HOME/.openclaw}" "$hermes_home"
    openclaw_apply_hermes_profile_cli_if_available "$(openclaw_lobster_shared_env_path)" "$hermes_home"
}

openclaw_role_skill_bundle_to_level() {
    case "$(printf "%s" "${1:-medium}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')" in
        low|basic|基础|base) echo "low" ;;
        high|super|高级|superpack) echo "high" ;;
        *) echo "medium" ;;
    esac
}

openclaw_hermes_role_profile_path() {
    local hermes_home="${1:-${HERMES_HOME:-$HOME/.hermes}}"
    echo "${hermes_home}/lobster-profile.env"
}

openclaw_hermes_role_readme_path() {
    local hermes_home="${1:-${HERMES_HOME:-$HOME/.hermes}}"
    echo "${hermes_home}/lobster-profile.md"
}

openclaw_hermes_runtime_manifest_path() {
    local hermes_home="${1:-${HERMES_HOME:-$HOME/.hermes}}"
    echo "${hermes_home}/lobster-runtime.env"
}

openclaw_hermes_skills_dir() {
    local hermes_home="${1:-${HERMES_HOME:-$HOME/.hermes}}"
    echo "${hermes_home}/skills"
}

openclaw_hermes_bin() {
    local candidate
    for candidate in \
        "${HERMES_BIN:-}" \
        "$(command -v hermes 2>/dev/null || true)" \
        "$HOME/.local/bin/hermes" \
        "$HOME/.cargo/bin/hermes" \
        "/usr/local/bin/hermes" \
        "/usr/bin/hermes"
    do
        [ -n "$candidate" ] || continue
        [ -x "$candidate" ] || continue
        echo "$candidate"
        return 0
    done
    return 1
}

openclaw_hermes_cli_available() {
    openclaw_hermes_bin >/dev/null 2>&1
}

openclaw_run_hermes_cli() {
    local hermes_home="$1"
    shift || true
    local hermes_bin
    hermes_bin="$(openclaw_hermes_bin)" || return 127
    HERMES_HOME="${hermes_home}" "$hermes_bin" "$@"
}

openclaw_hermes_managed_toolsets() {
    cat <<'EOF'
web
browser
terminal
file
code_execution
vision
image_gen
skills
todo
memory
session_search
clarify
delegation
cronjob
messaging
EOF
}

openclaw_hermes_role_toolsets() {
    local role="${1:-druid}"
    case "$role" in
        druid)
            echo "web browser terminal file skills todo memory messaging"
            ;;
        assassin)
            echo "web browser file code_execution memory session_search clarify"
            ;;
        mage)
            echo "web browser file vision skills memory session_search todo"
            ;;
        summoner)
            echo "browser file skills todo memory messaging cronjob delegation"
            ;;
        warrior)
            echo "web browser terminal file code_execution skills memory delegation"
            ;;
        paladin)
            echo "web browser file image_gen skills messaging todo memory"
            ;;
        designer)
            echo "web browser file vision image_gen skills memory"
            ;;
        *)
            openclaw_hermes_role_toolsets "druid"
            ;;
    esac
}

openclaw_hermes_rule_profile_defaults() {
    local profile
    profile="$(openclaw_normalize_rule_profile_level "${1:-medium}")"
    case "$profile" in
        low)
            cat <<'EOF'
DELEGATION_REASONING=low
DELEGATION_MAX_ITERATIONS=12
AGENT_MAX_TURNS=60
EOF
            ;;
        high)
            cat <<'EOF'
DELEGATION_REASONING=high
DELEGATION_MAX_ITERATIONS=60
AGENT_MAX_TURNS=150
EOF
            ;;
        none)
            cat <<'EOF'
DELEGATION_REASONING=low
DELEGATION_MAX_ITERATIONS=8
AGENT_MAX_TURNS=40
EOF
            ;;
        *)
            cat <<'EOF'
DELEGATION_REASONING=medium
DELEGATION_MAX_ITERATIONS=30
AGENT_MAX_TURNS=90
EOF
            ;;
    esac
}

openclaw_hermes_profile_role_defaults() {
    local role="${1:-druid}"
    case "$role" in
        druid)
            cat <<'EOF'
PROFILE_NAME=generalist-druid
PROFILE_SUMMARY=通用总管，适合大多数任务协同与多面执行。
PRIMARY_MODEL_HINT=openai:GPT-5.4
SECONDARY_MODEL_HINT=minimax:MiniMax-M1
TOOLSET_HINT=web,browser,terminal,file,skills,todo,memory,messaging
SKILL_FOCUS=coordination,search,writing,ops
EOF
            ;;
        assassin)
            cat <<'EOF'
PROFILE_NAME=analyst-assassin
PROFILE_SUMMARY=研究、投资、数据检索和机会挖掘优先。
PRIMARY_MODEL_HINT=openai:GPT-5.4
SECONDARY_MODEL_HINT=openrouter:deep-research
TOOLSET_HINT=web,browser,file,code_execution,memory,session_search,clarify
SKILL_FOCUS=analysis,research,valuation,monitoring
EOF
            ;;
        mage)
            cat <<'EOF'
PROFILE_NAME=research-mage
PROFILE_SUMMARY=论文、长文、知识整理和学术研究优先。
PRIMARY_MODEL_HINT=openai:GPT-5.4
SECONDARY_MODEL_HINT=google:gemini-2.5-pro
TOOLSET_HINT=web,browser,file,vision,skills,memory,session_search,todo
SKILL_FOCUS=research,writing,study,knowledge
EOF
            ;;
        summoner)
            cat <<'EOF'
PROFILE_NAME=manager-summoner
PROFILE_SUMMARY=团队管理、招聘、流程和项目推进优先。
PRIMARY_MODEL_HINT=openai:GPT-5.4
SECONDARY_MODEL_HINT=openrouter:project-ops
TOOLSET_HINT=browser,file,skills,todo,memory,messaging,cronjob,delegation
SKILL_FOCUS=management,recruiting,planning,coordination
EOF
            ;;
        warrior)
            cat <<'EOF'
PROFILE_NAME=engineer-warrior
PROFILE_SUMMARY=工程实现、调试、测试与交付优先。
PRIMARY_MODEL_HINT=openai:GPT-5.4
SECONDARY_MODEL_HINT=minimax:MiniMax-M1
TOOLSET_HINT=web,browser,terminal,file,code_execution,skills,memory,delegation
SKILL_FOCUS=engineering,debugging,delivery,verification
EOF
            ;;
        paladin)
            cat <<'EOF'
PROFILE_NAME=growth-paladin
PROFILE_SUMMARY=市场增长、内容分发、SEO和运营优先。
PRIMARY_MODEL_HINT=openai:GPT-5.4
SECONDARY_MODEL_HINT=google:gemini-2.5-pro
TOOLSET_HINT=web,browser,file,image_gen,skills,messaging,todo,memory
SKILL_FOCUS=growth,marketing,seo,content
EOF
            ;;
        designer)
            cat <<'EOF'
PROFILE_NAME=designer-ranger
PROFILE_SUMMARY=视觉设计、前端设计、图像创作和内容包装优先。
PRIMARY_MODEL_HINT=google:gemini-2.5-flash-image
SECONDARY_MODEL_HINT=minimax:MiniMax-VL
TOOLSET_HINT=web,browser,file,vision,image_gen,skills,memory
SKILL_FOCUS=design,visual,image,frontend
EOF
            ;;
        *)
            openclaw_hermes_profile_role_defaults "druid"
            ;;
    esac
}

openclaw_sync_hermes_role_profile() {
    local shared_env="${1:-$(openclaw_lobster_shared_env_path)}"
    local hermes_home="${2:-${HERMES_HOME:-$HOME/.hermes}}"
    mkdir -p "$hermes_home" 2>/dev/null || return 1

    local role skill_pack rule_profile
    local runtime_file max_requests max_tokens max_tokens_per_request max_image_requests max_video_requests
    local window_hours context_warn_tokens context_ask_tokens context_force_tokens context_ask_command
    local profile_skill_list profile_skill_count skill_pack_label image_api_url image_model skills_bridge_dir
    role="$(openclaw_read_shell_kv_value OPENCLAW_PERSONA_ROLE "$shared_env")"
    [ -n "$role" ] || role="druid"
    skill_pack="$(openclaw_read_shell_kv_value OPENCLAW_WEB_SKILL_PACK "$shared_env")"
    [ -n "$skill_pack" ] || skill_pack="$(openclaw_read_shell_kv_value OPENCLAW_RULE_PROFILE "$shared_env")"
    skill_pack="$(openclaw_role_skill_bundle_to_level "$skill_pack")"
    rule_profile="$(openclaw_read_shell_kv_value OPENCLAW_RULE_PROFILE "$shared_env")"
    [ -n "$rule_profile" ] || rule_profile="medium"
    runtime_file="$(openclaw_hermes_runtime_manifest_path "$hermes_home")"
    window_hours="$(openclaw_read_shell_kv_value OPENCLAW_RULE_WINDOW_HOURS "$shared_env")"
    max_requests="$(openclaw_read_shell_kv_value OPENCLAW_RULE_MAX_REQUESTS "$shared_env")"
    max_tokens="$(openclaw_read_shell_kv_value OPENCLAW_RULE_MAX_TOKENS "$shared_env")"
    max_tokens_per_request="$(openclaw_read_shell_kv_value OPENCLAW_RULE_MAX_TOKENS_PER_REQUEST "$shared_env")"
    max_image_requests="$(openclaw_read_shell_kv_value OPENCLAW_RULE_MAX_IMAGE_REQUESTS "$shared_env")"
    max_video_requests="$(openclaw_read_shell_kv_value OPENCLAW_RULE_MAX_VIDEO_REQUESTS "$shared_env")"
    context_warn_tokens="$(openclaw_read_shell_kv_value OPENCLAW_CONTEXT_WARN_TOKENS "$shared_env")"
    context_ask_tokens="$(openclaw_read_shell_kv_value OPENCLAW_CONTEXT_ASK_TOKENS "$shared_env")"
    context_force_tokens="$(openclaw_read_shell_kv_value OPENCLAW_CONTEXT_FORCE_TOKENS "$shared_env")"
    context_ask_command="$(openclaw_read_shell_kv_value OPENCLAW_CONTEXT_ASK_COMMAND "$shared_env")"
    profile_skill_list="$(openclaw_read_shell_kv_value OPENCLAW_PROFILE_SKILL_LIST "$shared_env")"
    profile_skill_count="$(openclaw_read_shell_kv_value OPENCLAW_PROFILE_SKILL_COUNT "$shared_env")"
    skill_pack_label="$(openclaw_read_shell_kv_value OPENCLAW_PROFILE_SKILL_PACK_LABEL "$shared_env")"
    image_api_url="$(openclaw_read_shell_kv_value OPENCLAW_IMAGE_API_URL "$shared_env")"
    image_model="$(openclaw_read_shell_kv_value OPENCLAW_IMAGE_MODEL "$shared_env")"
    skills_bridge_dir="${OPENCLAW_HOME:-$HOME/.openclaw}/skills"

    local profile_file readme_file tmp_file summary role_block
    profile_file="$(openclaw_hermes_role_profile_path "$hermes_home")"
    readme_file="$(openclaw_hermes_role_readme_path "$hermes_home")"
    tmp_file="$(mktemp)"
    role_block="$(openclaw_hermes_profile_role_defaults "$role")"
    summary="$(printf "%s\n" "$role_block" | awk -F= '/^PROFILE_SUMMARY=/{print substr($0, index($0,"=")+1)}')"

    {
        echo "# Generated by Lobster role/profile mapper"
        printf "%s\n" "$role_block"
        echo "LOBSTER_PERSONA_ROLE=\"$(openclaw_escape_env_value "$role")\""
        echo "LOBSTER_SKILL_PACK_LEVEL=\"$(openclaw_escape_env_value "$skill_pack")\""
        echo "LOBSTER_RULE_PROFILE=\"$(openclaw_escape_env_value "$rule_profile")\""
        echo "LOBSTER_ROLE_CORE_SKILLS=\"$(openclaw_escape_env_value "$(openclaw_read_shell_kv_value OPENCLAW_ROLE_CORE_SKILLS "$shared_env")")\""
        echo "LOBSTER_ROLE_EXTRA_SKILLS=\"$(openclaw_escape_env_value "$(openclaw_read_shell_kv_value OPENCLAW_ROLE_EXTRA_SKILLS "$shared_env")")\""
        echo "LOBSTER_RULE_WINDOW_HOURS=\"$(openclaw_escape_env_value "$window_hours")\""
        echo "LOBSTER_RULE_MAX_REQUESTS=\"$(openclaw_escape_env_value "$max_requests")\""
        echo "LOBSTER_RULE_MAX_TOKENS=\"$(openclaw_escape_env_value "$max_tokens")\""
        echo "LOBSTER_RULE_MAX_TOKENS_PER_REQUEST=\"$(openclaw_escape_env_value "$max_tokens_per_request")\""
        echo "LOBSTER_RULE_MAX_IMAGE_REQUESTS=\"$(openclaw_escape_env_value "$max_image_requests")\""
        echo "LOBSTER_RULE_MAX_VIDEO_REQUESTS=\"$(openclaw_escape_env_value "$max_video_requests")\""
        echo "LOBSTER_CONTEXT_WARN_TOKENS=\"$(openclaw_escape_env_value "$context_warn_tokens")\""
        echo "LOBSTER_CONTEXT_ASK_TOKENS=\"$(openclaw_escape_env_value "$context_ask_tokens")\""
        echo "LOBSTER_CONTEXT_FORCE_TOKENS=\"$(openclaw_escape_env_value "$context_force_tokens")\""
        echo "LOBSTER_CONTEXT_ASK_COMMAND=\"$(openclaw_escape_env_value "$context_ask_command")\""
        echo "LOBSTER_SKILL_PACK_LABEL=\"$(openclaw_escape_env_value "$skill_pack_label")\""
        echo "LOBSTER_PROFILE_SKILL_LIST=\"$(openclaw_escape_env_value "$profile_skill_list")\""
        echo "LOBSTER_PROFILE_SKILL_COUNT=\"$(openclaw_escape_env_value "$profile_skill_count")\""
        echo "LOBSTER_SKILLS_BRIDGE_MODE=\"symlink\""
        echo "LOBSTER_SKILLS_BRIDGE_DIR=\"$(openclaw_escape_env_value "$skills_bridge_dir")\""
        echo "LOBSTER_IMAGE_API_URL=\"$(openclaw_escape_env_value "$image_api_url")\""
        echo "LOBSTER_IMAGE_MODEL=\"$(openclaw_escape_env_value "$image_model")\""
        echo "LOBSTER_ADVANCED_MODEL_URL=\"$(openclaw_escape_env_value "$(openclaw_read_shell_kv_value OPENCLAW_RULE_ADVANCED_MODEL_API_URL "$shared_env")")\""
        echo "LOBSTER_ADVANCED_MODEL_NAME=\"$(openclaw_escape_env_value "$(openclaw_read_shell_kv_value OPENCLAW_RULE_ADVANCED_MODEL_NAME "$shared_env")")\""
        echo "LOBSTER_ADVANCED_MODEL_TRIGGER=\"$(openclaw_escape_env_value "$(openclaw_read_shell_kv_value OPENCLAW_BM_COMMAND "$shared_env")")\""
    } > "$tmp_file"
    mv "$tmp_file" "$profile_file"
    chmod 600 "$profile_file" 2>/dev/null || true

    cat > "$runtime_file" <<EOF
# Generated by Lobster shared control layer
LOBSTER_PERSONA_ROLE="$(openclaw_escape_env_value "$role")"
LOBSTER_RULE_PROFILE="$(openclaw_escape_env_value "$rule_profile")"
LOBSTER_SKILL_PACK_LEVEL="$(openclaw_escape_env_value "$skill_pack")"
LOBSTER_SKILL_PACK_LABEL="$(openclaw_escape_env_value "$skill_pack_label")"
LOBSTER_PROFILE_SKILL_COUNT="$(openclaw_escape_env_value "$profile_skill_count")"
LOBSTER_PROFILE_SKILL_LIST="$(openclaw_escape_env_value "$profile_skill_list")"
LOBSTER_SKILLS_BRIDGE_MODE="symlink"
LOBSTER_SKILLS_BRIDGE_DIR="$(openclaw_escape_env_value "$skills_bridge_dir")"
LOBSTER_RULE_WINDOW_HOURS="$(openclaw_escape_env_value "$window_hours")"
LOBSTER_RULE_MAX_REQUESTS="$(openclaw_escape_env_value "$max_requests")"
LOBSTER_RULE_MAX_TOKENS="$(openclaw_escape_env_value "$max_tokens")"
LOBSTER_RULE_MAX_TOKENS_PER_REQUEST="$(openclaw_escape_env_value "$max_tokens_per_request")"
LOBSTER_RULE_MAX_IMAGE_REQUESTS="$(openclaw_escape_env_value "$max_image_requests")"
LOBSTER_RULE_MAX_VIDEO_REQUESTS="$(openclaw_escape_env_value "$max_video_requests")"
LOBSTER_CONTEXT_WARN_TOKENS="$(openclaw_escape_env_value "$context_warn_tokens")"
LOBSTER_CONTEXT_ASK_TOKENS="$(openclaw_escape_env_value "$context_ask_tokens")"
LOBSTER_CONTEXT_FORCE_TOKENS="$(openclaw_escape_env_value "$context_force_tokens")"
LOBSTER_CONTEXT_ASK_COMMAND="$(openclaw_escape_env_value "$context_ask_command")"
LOBSTER_IMAGE_API_URL="$(openclaw_escape_env_value "$image_api_url")"
LOBSTER_IMAGE_MODEL="$(openclaw_escape_env_value "$image_model")"
EOF
    chmod 600 "$runtime_file" 2>/dev/null || true

    cat > "$readme_file" <<EOF
# Lobster -> Hermes Profile

- 角色: ${role}
- 技能包档位: ${skill_pack}
- 技能包标签: ${skill_pack_label:-未命名}
- 解析技能数: ${profile_skill_count:-0}
- 技能桥接: symlink -> ${skills_bridge_dir}
- 规则档位: ${rule_profile}
- 请求额度: ${window_hours:-0} 小时 / ${max_requests:-0} 次
- 多媒体额度: 图片 ${max_image_requests:-0} / 视频 ${max_video_requests:-0}
- 上下文阈值: warn ${context_warn_tokens:-0} / ask ${context_ask_tokens:-0} / force ${context_force_tokens:-0}
- 生图配置: ${image_model:-未配置} @ ${image_api_url:-未配置}
- 角色摘要: ${summary}

## 说明

此文件由 Lobster 控制层自动生成，用于给 Hermes 提供稳定的角色/技能/规则映射提示。
当前阶段不会强制写入未知的 Hermes 内部 config schema，而是：

1. 生成 \`.env\` 提供 provider/key/base_url
2. 生成本角色 profile 文件提供模型/toolset/技能焦点建议
3. 生成 \`lobster-runtime.env\` 作为技能包/额度/上下文阈值兼容清单
4. 允许后续通过 \`hermes model\` / \`hermes tools\` / \`hermes config set\` 做更深层设置
EOF
    chmod 600 "$readme_file" 2>/dev/null || true
}


openclaw_install_hermes_openai_bridge() {
    local hermes_home="${1:-${HERMES_HOME:-$HOME/.hermes}}"
    local bridge_port="${2:-${HERMES_CHAT_PORT:-8000}}"
    local bridge_host="${3:-127.0.0.1}"
    local model="${4:-MiniMax-M2.7}"
    local provider="${5:-minimax}"
    local install_dir="${OPENCLAW_HERMES_BRIDGE_DIR:-/opt/openclaw-hermes-bridge}"
    local service_name="${OPENCLAW_HERMES_BRIDGE_SERVICE:-openclaw-hermes-openai.service}"

    [ -n "$bridge_port" ] || bridge_port="8000"
    [ -n "$bridge_host" ] || bridge_host="127.0.0.1"
    [ -n "$model" ] || model="MiniMax-M2.7"
    [ -n "$provider" ] || provider="minimax"

    if ! command -v python3 >/dev/null 2>&1; then
        return 1
    fi
    if ! command -v systemctl >/dev/null 2>&1; then
        return 1
    fi
    if ! openclaw_hermes_cli_available; then
        return 127
    fi

    mkdir -p "$install_dir" 2>/dev/null || return 1
    cat >"$install_dir/openai_bridge.py" <<'PYBRIDGE'
#!/usr/bin/env python3
import json
import os
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ.get("HERMES_OPENAI_BRIDGE_HOST", "127.0.0.1")
PORT = int(os.environ.get("HERMES_OPENAI_BRIDGE_PORT", "8000"))
MODEL = os.environ.get("HERMES_OPENAI_BRIDGE_MODEL", "MiniMax-M2.7")
PROVIDER = os.environ.get("HERMES_OPENAI_BRIDGE_PROVIDER", "minimax")
TIMEOUT = int(os.environ.get("HERMES_OPENAI_BRIDGE_TIMEOUT", "115"))
HERMES_BIN = os.environ.get("HERMES_BIN", "hermes")


def respond(handler, status, payload, content_type="application/json; charset=utf-8"):
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "authorization, content-type")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    handler.end_headers()
    handler.wfile.write(data)


def respond_sse(handler, completion):
    message = completion.get("choices", [{}])[0].get("message", {})
    content = str(message.get("content") or "")
    created = completion.get("created") or int(time.time())
    model = completion.get("model") or "hermes-agent"
    completion_id = completion.get("id") or f"chatcmpl-hermes-{created}"
    usage = completion.get("usage") or {}
    handler.send_response(200)
    handler.send_header("Content-Type", "text/event-stream; charset=utf-8")
    handler.send_header("Cache-Control", "no-cache")
    handler.send_header("Connection", "close")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "authorization, content-type")
    handler.end_headers()
    first = {"id": completion_id, "object": "chat.completion.chunk", "created": created, "model": model, "choices": [{"index": 0, "delta": {"role": "assistant", "content": content}, "finish_reason": None}]}
    final = {"id": completion_id, "object": "chat.completion.chunk", "created": created, "model": model, "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}], "usage": usage}
    for payload in (first, final):
        handler.wfile.write(("data: " + json.dumps(payload, ensure_ascii=False) + "\n\n").encode("utf-8"))
        handler.wfile.flush()
    handler.wfile.write(b"data: [DONE]\n\n")
    handler.wfile.flush()
    handler.close_connection = True


def text_from_content(content):
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        out = []
        for part in content:
            if isinstance(part, dict) and part.get("type") == "text":
                out.append(str(part.get("text") or ""))
        return "\n".join(x for x in out if x).strip()
    return ""


def build_prompt(messages):
    rows = []
    for message in messages[-12:]:
        if not isinstance(message, dict):
            continue
        role = str(message.get("role") or "user").strip() or "user"
        text = text_from_content(message.get("content"))
        if text:
            rows.append((role, text))
    if not rows:
        return "请回复 OK"
    if len(rows) == 1:
        return rows[-1][1]
    labels = {"system": "系统", "user": "用户", "assistant": "助手"}
    lines = ["请根据以下对话上下文继续回复最后一条用户消息。"]
    for role, text in rows:
        lines.append(f"{labels.get(role, role)}: {text}")
    return "\n".join(lines)


class Handler(BaseHTTPRequestHandler):
    server_version = "OpenClawHermesOpenAIBridge/1.1"

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)

    def do_OPTIONS(self):
        respond(self, 200, {"ok": True})

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/health", "/v1/health"):
            return respond(self, 200, {"ok": True, "model": MODEL, "provider": PROVIDER})
        if path == "/v1/models":
            now = int(time.time())
            return respond(self, 200, {"object": "list", "data": [
                {"id": "hermes-agent", "object": "model", "created": now, "owned_by": "hermes"},
                {"id": MODEL, "object": "model", "created": now, "owned_by": PROVIDER},
            ]})
        return respond(self, 404, {"error": {"message": "Not Found", "type": "not_found"}})

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        if path != "/v1/chat/completions":
            return respond(self, 404, {"error": {"message": "Not Found", "type": "not_found"}})
        length = int(self.headers.get("content-length") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            body = json.loads(raw.decode("utf-8") or "{}")
        except Exception:
            return respond(self, 400, {"error": {"message": "Invalid JSON", "type": "invalid_request_error"}})
        messages = body.get("messages") if isinstance(body, dict) else None
        if not isinstance(messages, list) or not messages:
            return respond(self, 400, {"error": {"message": "messages is required", "type": "invalid_request_error"}})
        prompt = build_prompt(messages)
        env = os.environ.copy()
        env["PATH"] = "/root/.local/bin:/usr/local/bin:" + env.get("PATH", "")
        try:
            proc = subprocess.run([HERMES_BIN, "-z", prompt, "--provider", PROVIDER, "-m", MODEL], text=True, capture_output=True, timeout=TIMEOUT, env=env, cwd=os.path.expanduser("~"))
        except subprocess.TimeoutExpired:
            return respond(self, 504, {"error": {"message": "Hermes request timeout", "type": "timeout"}})
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout or "Hermes request failed").strip()[-1000:]
            return respond(self, 502, {"error": {"message": detail, "type": "hermes_error"}})
        content = (proc.stdout or "").strip()
        created = int(time.time())
        prompt_tokens = max(1, len(prompt) // 4)
        completion_tokens = max(1, len(content) // 4)
        completion = {
            "id": f"chatcmpl-hermes-{created}",
            "object": "chat.completion",
            "created": created,
            "model": body.get("model") or "hermes-agent",
            "choices": [{"index": 0, "message": {"role": "assistant", "content": content}, "finish_reason": "stop"}],
            "usage": {"prompt_tokens": prompt_tokens, "completion_tokens": completion_tokens, "total_tokens": prompt_tokens + completion_tokens},
        }
        if bool(body.get("stream")):
            return respond_sse(self, completion)
        return respond(self, 200, completion)


if __name__ == "__main__":
    print(f"OpenClaw Hermes OpenAI bridge listening on {HOST}:{PORT}, model={MODEL}, provider={PROVIDER}", flush=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
PYBRIDGE
    chmod +x "$install_dir/openai_bridge.py" 2>/dev/null || true

    if [ "$(id -u 2>/dev/null || echo 1)" != "0" ]; then
        return 0
    fi

    cat >"/etc/systemd/system/$service_name" <<SERVICE
[Unit]
Description=OpenClaw Hermes OpenAI-compatible bridge
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=-$hermes_home/.env
Environment=HERMES_OPENAI_BRIDGE_HOST=$bridge_host
Environment=HERMES_OPENAI_BRIDGE_PORT=$bridge_port
Environment=HERMES_OPENAI_BRIDGE_PROVIDER=$provider
Environment=HERMES_OPENAI_BRIDGE_MODEL=$model
ExecStart=/usr/bin/python3 $install_dir/openai_bridge.py
Restart=always
RestartSec=3
User=root
WorkingDirectory=$HOME

[Install]
WantedBy=multi-user.target
SERVICE
    systemctl daemon-reload >/dev/null 2>&1 || return 1
    systemctl enable --now "$service_name" >/dev/null 2>&1 || return 1
    systemctl restart "$service_name" >/dev/null 2>&1 || return 1
}

openclaw_apply_hermes_default_model_from_env() {
    local shared_env="${1:-$(openclaw_lobster_shared_env_path)}"
    local hermes_home="${2:-${HERMES_HOME:-$HOME/.hermes}}"
    local hermes_env preset model base_url provider
    openclaw_hermes_cli_available || return 127
    hermes_env="$(openclaw_hermes_env_path "$hermes_home")"

    preset="$(openclaw_read_shell_kv_value OPENCLAW_ACTIVE_PROVIDER_PRESET "$hermes_env")"
    model="$(openclaw_read_shell_kv_value OPENCLAW_ACTIVE_PROVIDER_MODEL "$hermes_env")"
    base_url="$(openclaw_read_shell_kv_value OPENCLAW_ACTIVE_PROVIDER_BASE_URL "$hermes_env")"

    if [ -z "$preset" ] && [ -f "$shared_env" ]; then
        preset="$(openclaw_read_shell_kv_value OPENCLAW_ACTIVE_PROVIDER_PRESET "$shared_env")"
        model="$(openclaw_read_shell_kv_value OPENCLAW_ACTIVE_PROVIDER_MODEL "$shared_env")"
        base_url="$(openclaw_read_shell_kv_value OPENCLAW_ACTIVE_PROVIDER_BASE_URL "$shared_env")"
    fi

    case "$preset" in
        minimax|minimax-cn) provider="minimax" ;;
        openai|anthropic|openrouter|gemini|deepseek|glm|zai) provider="$preset" ;;
        *) provider="" ;;
    esac
    [ -n "$provider" ] || return 0
    [ -n "$model" ] || return 0
    openclaw_run_hermes_cli "$hermes_home" config set model.default "$model" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set model.provider "$provider" >/dev/null 2>&1 || return 1
    if [ -n "$base_url" ]; then
        openclaw_run_hermes_cli "$hermes_home" config set model.base_url "$base_url" >/dev/null 2>&1 || return 1
    fi
}

openclaw_apply_hermes_profile_cli() {
    local shared_env="${1:-$(openclaw_lobster_shared_env_path)}"
    local hermes_home="${2:-${HERMES_HOME:-$HOME/.hermes}}"
    local profile_file role profile_name profile_summary primary_model secondary_model
    local toolset_hint skill_focus skill_pack rule_profile advanced_url advanced_model advanced_key
    local reasoning max_iterations agent_max_turns desired_toolsets enable_toolsets disable_toolsets ts
    local window_hours max_requests max_tokens max_tokens_per_request max_image_requests max_video_requests
    local context_warn_tokens context_ask_tokens context_force_tokens context_ask_command
    local profile_skill_list profile_skill_count skill_pack_label image_api_url image_model skills_bridge_dir

    [ -f "$shared_env" ] || return 1
    profile_file="$(openclaw_hermes_role_profile_path "$hermes_home")"
    [ -f "$profile_file" ] || return 1
    openclaw_hermes_cli_available || return 127

    role="$(openclaw_read_shell_kv_value LOBSTER_PERSONA_ROLE "$profile_file")"
    [ -n "$role" ] || role="$(openclaw_read_shell_kv_value OPENCLAW_PERSONA_ROLE "$shared_env")"
    [ -n "$role" ] || role="druid"
    skill_pack="$(openclaw_read_shell_kv_value LOBSTER_SKILL_PACK_LEVEL "$profile_file")"
    [ -n "$skill_pack" ] || skill_pack="medium"
    rule_profile="$(openclaw_read_shell_kv_value LOBSTER_RULE_PROFILE "$profile_file")"
    [ -n "$rule_profile" ] || rule_profile="medium"

    profile_name="$(openclaw_read_shell_kv_value PROFILE_NAME "$profile_file")"
    profile_summary="$(openclaw_read_shell_kv_value PROFILE_SUMMARY "$profile_file")"
    primary_model="$(openclaw_read_shell_kv_value PRIMARY_MODEL_HINT "$profile_file")"
    secondary_model="$(openclaw_read_shell_kv_value SECONDARY_MODEL_HINT "$profile_file")"
    toolset_hint="$(openclaw_read_shell_kv_value TOOLSET_HINT "$profile_file")"
    skill_focus="$(openclaw_read_shell_kv_value SKILL_FOCUS "$profile_file")"

    advanced_url="$(openclaw_read_shell_kv_value LOBSTER_ADVANCED_MODEL_URL "$profile_file")"
    advanced_model="$(openclaw_read_shell_kv_value LOBSTER_ADVANCED_MODEL_NAME "$profile_file")"
    advanced_key="$(openclaw_read_shell_kv_value OPENCLAW_RULE_ADVANCED_MODEL_API_KEY "$shared_env")"
    [ -n "$advanced_key" ] || advanced_key="$(openclaw_read_shell_kv_value OPENAI_API_KEY "$shared_env")"
    window_hours="$(openclaw_read_shell_kv_value LOBSTER_RULE_WINDOW_HOURS "$profile_file")"
    max_requests="$(openclaw_read_shell_kv_value LOBSTER_RULE_MAX_REQUESTS "$profile_file")"
    max_tokens="$(openclaw_read_shell_kv_value LOBSTER_RULE_MAX_TOKENS "$profile_file")"
    max_tokens_per_request="$(openclaw_read_shell_kv_value LOBSTER_RULE_MAX_TOKENS_PER_REQUEST "$profile_file")"
    max_image_requests="$(openclaw_read_shell_kv_value LOBSTER_RULE_MAX_IMAGE_REQUESTS "$profile_file")"
    max_video_requests="$(openclaw_read_shell_kv_value LOBSTER_RULE_MAX_VIDEO_REQUESTS "$profile_file")"
    context_warn_tokens="$(openclaw_read_shell_kv_value LOBSTER_CONTEXT_WARN_TOKENS "$profile_file")"
    context_ask_tokens="$(openclaw_read_shell_kv_value LOBSTER_CONTEXT_ASK_TOKENS "$profile_file")"
    context_force_tokens="$(openclaw_read_shell_kv_value LOBSTER_CONTEXT_FORCE_TOKENS "$profile_file")"
    context_ask_command="$(openclaw_read_shell_kv_value LOBSTER_CONTEXT_ASK_COMMAND "$profile_file")"
    profile_skill_list="$(openclaw_read_shell_kv_value LOBSTER_PROFILE_SKILL_LIST "$profile_file")"
    profile_skill_count="$(openclaw_read_shell_kv_value LOBSTER_PROFILE_SKILL_COUNT "$profile_file")"
    skill_pack_label="$(openclaw_read_shell_kv_value LOBSTER_SKILL_PACK_LABEL "$profile_file")"
    skills_bridge_dir="$(openclaw_read_shell_kv_value LOBSTER_SKILLS_BRIDGE_DIR "$profile_file")"
    image_api_url="$(openclaw_read_shell_kv_value LOBSTER_IMAGE_API_URL "$profile_file")"
    image_model="$(openclaw_read_shell_kv_value LOBSTER_IMAGE_MODEL "$profile_file")"

    eval "$(openclaw_hermes_rule_profile_defaults "$rule_profile")"
    desired_toolsets="$(openclaw_hermes_role_toolsets "$role")"

    openclaw_apply_hermes_default_model_from_env "$shared_env" "$hermes_home" >/dev/null 2>&1 || true

    openclaw_run_hermes_cli "$hermes_home" config set lobster.profile_name "$profile_name" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.profile_summary "$profile_summary" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.persona_role "$role" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.skill_pack_level "$skill_pack" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.skill_pack_label "$skill_pack_label" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.skill_pack_resolved "$profile_skill_list" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.skill_count "$profile_skill_count" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.skills_bridge_mode "symlink" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.skills_bridge_dir "$skills_bridge_dir" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.rule_profile "$rule_profile" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.rate.window_hours "$window_hours" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.rate.max_requests "$max_requests" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.rate.max_tokens "$max_tokens" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.rate.max_tokens_per_request "$max_tokens_per_request" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.media.max_image_requests "$max_image_requests" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.media.max_video_requests "$max_video_requests" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.context.warn_tokens "$context_warn_tokens" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.context.ask_tokens "$context_ask_tokens" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.context.force_tokens "$context_force_tokens" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.context.ask_command "$context_ask_command" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.primary_model_hint "$primary_model" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.secondary_model_hint "$secondary_model" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.toolset_hint "$toolset_hint" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.skill_focus "$skill_focus" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.image.api_url "$image_api_url" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set lobster.image.model "$image_model" >/dev/null 2>&1 || return 1

    openclaw_run_hermes_cli "$hermes_home" config set delegation.reasoning_effort "$DELEGATION_REASONING" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set delegation.max_iterations "$DELEGATION_MAX_ITERATIONS" >/dev/null 2>&1 || return 1
    openclaw_run_hermes_cli "$hermes_home" config set agent.max_turns "$AGENT_MAX_TURNS" >/dev/null 2>&1 || return 1

    if [ -n "$advanced_url" ] && [ -n "$advanced_model" ]; then
        openclaw_run_hermes_cli "$hermes_home" config set delegation.base_url "$advanced_url" >/dev/null 2>&1 || return 1
        openclaw_run_hermes_cli "$hermes_home" config set delegation.model "$advanced_model" >/dev/null 2>&1 || return 1
        openclaw_run_hermes_cli "$hermes_home" config set delegation.api_key "$advanced_key" >/dev/null 2>&1 || return 1
    else
        openclaw_run_hermes_cli "$hermes_home" config set delegation.base_url "" >/dev/null 2>&1 || return 1
        openclaw_run_hermes_cli "$hermes_home" config set delegation.model "" >/dev/null 2>&1 || return 1
        openclaw_run_hermes_cli "$hermes_home" config set delegation.api_key "" >/dev/null 2>&1 || return 1
    fi

    enable_toolsets=()
    disable_toolsets=()
    for ts in $(openclaw_hermes_managed_toolsets); do
        if printf ' %s ' "$desired_toolsets" | grep -Fq " ${ts} "; then
            enable_toolsets+=("$ts")
        else
            disable_toolsets+=("$ts")
        fi
    done

    if [ "${#enable_toolsets[@]}" -gt 0 ]; then
        openclaw_run_hermes_cli "$hermes_home" tools enable "${enable_toolsets[@]}" --platform cli >/dev/null 2>&1 || return 1
    fi
    if [ "${#disable_toolsets[@]}" -gt 0 ]; then
        openclaw_run_hermes_cli "$hermes_home" tools disable "${disable_toolsets[@]}" --platform cli >/dev/null 2>&1 || return 1
    fi
}

openclaw_apply_hermes_profile_cli_if_available() {
    local shared_env="${1:-$(openclaw_lobster_shared_env_path)}"
    local hermes_home="${2:-${HERMES_HOME:-$HOME/.hermes}}"

    if ! openclaw_hermes_cli_available; then
        return 0
    fi
    openclaw_apply_hermes_profile_cli "$shared_env" "$hermes_home"
}
