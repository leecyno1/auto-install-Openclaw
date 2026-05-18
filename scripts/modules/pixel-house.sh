#!/usr/bin/env bash
#===============================================================================
# 像素小屋模块 - Pixel House Module
#
# 职责：
# - 安装像素小屋工作台（独立部署）
# - 与 OpenClaw 运行时挂钩
# - 生命周期管理（install/start/stop/status）
#
# CLI 用法：
#   openclaw-setup config pixel-house --install
#   openclaw-setup config pixel-house --start
#   openclaw-setup config pixel-house --stop
#   openclaw-setup config pixel-house --status
#===============================================================================

set -euo pipefail

# 脚本目录和仓库根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 像素小屋相关路径
PIXEL_HOUSE_SOURCE="$REPO_ROOT/subprojects/lobster-sanctum-ui"
PIXEL_HOUSE_TARGET="$HOME/.openclaw/pixel-house"
PIXEL_HOUSE_LAUNCHER="$HOME/.openclaw/lobster-world.sh"

# 默认配置
DEFAULT_PORT="19000"
BACKEND_REQUIREMENTS="$PIXEL_HOUSE_SOURCE/vendor/star-office-ui/backend/requirements.txt"

#===============================================================================
# 日志函数
#===============================================================================

log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[SUCCESS] $*"
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

#===============================================================================
# 辅助函数
#===============================================================================

ensure_dir() {
    mkdir -p "$1"
}

is_port_in_use() {
    local port="$1"
    if command -v lsof >/dev/null 2>&1; then
        lsof -i ":$port" >/dev/null 2>&1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -an 2>/dev/null | grep -q ":$port "
    else
        return 1
    fi
}

check_python_version() {
    local min_version="3.10"
    local current_version
    current_version="$(python3 --version 2>&1 | awk '{print $2}')"

    if [[ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" != "$min_version" ]]; then
        log_error "Python $min_version+ required, found: $current_version"
        return 1
    fi

    log_info "Python version: $current_version"
}

#===============================================================================
# 安装像素小屋
#===============================================================================

install_pixel_house() {
    log_info "Installing Pixel House..."

    # 检查源码目录
    if [ ! -d "$PIXEL_HOUSE_SOURCE" ]; then
        log_error "Pixel House source not found: $PIXEL_HOUSE_SOURCE"
        return 1
    fi

    # 创建目标目录
    ensure_dir "$PIXEL_HOUSE_TARGET"

    # 复制源码
    log_info "Copying Pixel House files..."
    rsync -av --exclude='.git' --exclude='node_modules' \
        "$PIXEL_HOUSE_SOURCE/" "$PIXEL_HOUSE_TARGET/" 2>/dev/null || \
        cp -R "$PIXEL_HOUSE_SOURCE"/* "$PIXEL_HOUSE_TARGET/"

    # 复制启动脚本
    if [ -f "$REPO_ROOT/scripts/lobster-world.sh" ]; then
        cp "$REPO_ROOT/scripts/lobster-world.sh" "$PIXEL_HOUSE_LAUNCHER"
        chmod +x "$PIXEL_HOUSE_LAUNCHER"
        log_info "Launcher installed: $PIXEL_HOUSE_LAUNCHER"
    fi

    # 安装 Python 依赖
    install_python_deps

    # 创建 OpenClaw 链接（如果需要）
    link_openclaw_config

    # 配置端口
    configure_port "$DEFAULT_PORT"

    log_success "Pixel House installed to: $PIXEL_HOUSE_TARGET"
    log_info "Run 'openclaw-setup config pixel-house --start' to start"
}

install_python_deps() {
    log_info "Installing Python dependencies..."

    # 检查 Python 版本
    check_python_version || return 1

    local backend_dir="$PIXEL_HOUSE_TARGET/vendor/star-office-ui/backend"

    if [ -f "$backend_dir/requirements.txt" ]; then
        # 创建虚拟环境
        local venv_dir="$backend_dir/.venv"

        if [ ! -d "$venv_dir" ]; then
            log_info "Creating virtual environment..."
            python3 -m venv "$venv_dir"
        fi

        # 安装依赖
        log_info "Installing packages..."
        "$venv_dir/bin/pip" install --upgrade pip -q
        "$venv_dir/bin/pip" install -r "$backend_dir/requirements.txt" -q

        log_success "Python dependencies installed"
    else
        log_warn "requirements.txt not found, skipping Python deps"
    fi
}

link_openclaw_config() {
    log_info "Linking OpenClaw configuration..."

    # 确保 profile 目录存在
    ensure_dir "$HOME/.openclaw/profile"

    # 创建符号链接到工作区
    if [ ! -L "$PIXEL_HOUSE_TARGET/workspace" ]; then
        ln -sf "$HOME/.openclaw" "$PIXEL_HOUSE_TARGET/workspace"
        log_info "Created symlink: workspace -> ~/.openclaw"
    fi
}

configure_port() {
    local port="${1:-$DEFAULT_PORT}"

    log_info "Configuring port: $port"

    # 检查端口是否被占用
    if is_port_in_use "$port"; then
        log_warn "Port $port is already in use"
        log_info "You can change the port in $PIXEL_HOUSE_LAUNCHER"
    fi

    # 配置环境变量
    export STAR_BACKEND_PORT="$port"
    export STAR_BACKEND_HOST="127.0.0.1"

    log_info "Port configured: $port"
}

#===============================================================================
# 启动/停止/状态
#===============================================================================

start_pixel_house() {
    log_info "Starting Pixel House..."

    # 检查是否已安装
    if [ ! -d "$PIXEL_HOUSE_TARGET" ]; then
        log_error "Pixel House not installed"
        log_info "Run 'openclaw-setup config pixel-house --install' first"
        return 1
    fi

    # 检查端口
    local port="${STAR_BACKEND_PORT:-$DEFAULT_PORT}"

    if is_port_in_use "$port"; then
        log_warn "Pixel House is already running on port $port"
        return 0
    fi

    # 使用启动脚本
    if [ -f "$PIXEL_HOUSE_LAUNCHER" ]; then
        bash "$PIXEL_HOUSE_LAUNCHER" start
    else
        log_error "Launcher not found: $PIXEL_HOUSE_LAUNCHER"
        return 1
    fi

    # 等待启动
    sleep 2

    # 验证启动
    if is_port_in_use "$port"; then
        log_success "Pixel House started on port $port"
        log_info "Access at: http://localhost:$port"
    else
        log_error "Pixel House failed to start"
        log_info "Check logs: tail -f /tmp/lobster-world-$port.log"
        return 1
    fi
}

stop_pixel_house() {
    log_info "Stopping Pixel House..."

    local port="${STAR_BACKEND_PORT:-$DEFAULT_PORT}"

    if [ -f "$PIXEL_HOUSE_LAUNCHER" ]; then
        bash "$PIXEL_HOUSE_LAUNCHER" stop 2>/dev/null || true
    fi

    # 也尝试通过 pkill
    pkill -f "lobster-world" 2>/dev/null || true
    pkill -f "star-office-ui" 2>/dev/null || true

    log_success "Pixel House stopped"
}

restart_pixel_house() {
    stop_pixel_house
    sleep 1
    start_pixel_house
}

status_pixel_house() {
    echo ""
    echo "=== Pixel House Status ==="
    echo ""

    # 检查安装状态
    if [ -d "$PIXEL_HOUSE_TARGET" ]; then
        echo "Installation: Installed"
        echo "Location: $PIXEL_HOUSE_TARGET"

        # 检查依赖
        local backend_dir="$PIXEL_HOUSE_TARGET/vendor/star-office-ui/backend"
        if [ -d "$backend_dir/.venv" ]; then
            echo "Python venv: Installed"
        else
            echo "Python venv: Not installed"
        fi
    else
        echo "Installation: Not installed"
    fi

    echo ""

    # 检查运行状态
    local port="${STAR_BACKEND_PORT:-$DEFAULT_PORT}"

    if is_port_in_use "$port"; then
        echo "Status: Running"
        echo "Port: $port"
        echo "URL: http://localhost:$port"

        # 健康检查
        if command -v curl >/dev/null 2>&1; then
            local health_status
            health_status="$(curl -s --connect-timeout 3 "http://localhost:$port/health" 2>/dev/null || echo '{"status":"unknown"}')"
            echo "Health: $health_status"
        fi
    else
        echo "Status: Stopped"
        echo "Port: $port"
    fi

    echo ""
}

#===============================================================================
# 帮助信息
#===============================================================================

show_help() {
    cat <<'EOF'
Pixel House Module

Usage:
  openclaw-setup config pixel-house [action]

Actions:
  --install              Install Pixel House workbench
  --start                Start Pixel House
  --stop                 Stop Pixel House
  --restart              Restart Pixel House
  --status               Show status
  --port <port>          Set port (default: 19000)
  --help, -h             Show this help message

Examples:
  # Install Pixel House
  openclaw-setup config pixel-house --install

  # Start Pixel House
  openclaw-setup config pixel-house --start

  # Check status
  openclaw-setup config pixel-house --status

  # Custom port
  openclaw-setup config pixel-house --start --port 19001

EOF
}

#===============================================================================
# 主函数
#===============================================================================

main() {
    local action=""
    local port=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install)
                action="install"
                ;;
            --start)
                action="start"
                ;;
            --stop)
                action="stop"
                ;;
            --restart)
                action="restart"
                ;;
            --status)
                action="status"
                ;;
            --port)
                port="$2"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done

    # 设置端口
    if [ -n "$port" ]; then
        export STAR_BACKEND_PORT="$port"
    fi

    # 执行动作
    case "$action" in
        install)
            install_pixel_house
            ;;
        start)
            start_pixel_house
            ;;
        stop)
            stop_pixel_house
            ;;
        restart)
            restart_pixel_house
            ;;
        status)
            status_pixel_house
            ;;
        *)
            show_help
            ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
