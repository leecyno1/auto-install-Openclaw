#!/bin/bash
#
# OpenClaw Health Check Server
# 提供 /health 端点，监控 Gateway 和工作台状态
#

set -euo pipefail

PORT="${HEALTH_PORT:-13146}"
PID_FILE="/tmp/openclaw-health.pid"
LOG_FILE="/tmp/openclaw-health.log"
OPENCLAW_HOME="$HOME/.openclaw"

start_server() {
    if pgrep -f "health-server.py" > /dev/null 2>&1; then
        echo "健康检查服务已在运行"
        return 0
    fi

    cat > /tmp/health-server.py << 'PYTHON_SCRIPT'
#!/usr/bin/env python3
import json
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            health = self.check_health()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(health).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def check_health(self):
        status = {
            "status": "healthy",
            "timestamp": subprocess.check_output(["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"]).decode().strip(),
            "services": {}
        }

        # 检查内部 Gateway (端口 13145)
        gateway_running = False
        try:
            result = subprocess.run(["lsof", "-i", ":13145"], capture_output=True, text=True)
            gateway_running = result.returncode == 0 and "LISTEN" in result.stdout
        except:
            pass
        status["services"]["gateway"] = {
            "status": "up" if gateway_running else "down",
            "port": 13145,
            "url": "http://127.0.0.1:13145",
            "role": "internal_upstream"
        }

        # 检查像素小屋 (端口 19000)
        workbench_running = False
        try:
            result = subprocess.run(["lsof", "-i", ":19000"], capture_output=True, text=True)
            workbench_running = result.returncode == 0 and "LISTEN" in result.stdout
        except:
            pass
        status["services"]["workbench"] = {
            "status": "up" if workbench_running else "down",
            "port": 19000,
            "url": "http://127.0.0.1:19000"
        }

        # 检查兼容配额代理服务 (端口 13147，默认不作为新安装入口)
        quota_enforcer_running = False
        try:
            result = subprocess.run(["lsof", "-i", ":13147"], capture_output=True, text=True)
            quota_enforcer_running = result.returncode == 0 and "LISTEN" in result.stdout
        except:
            pass
        status["services"]["quota_enforcer"] = {
            "status": "up" if quota_enforcer_running else "down",
            "port": 13147,
            "url": "http://127.0.0.1:13147/health",
            "role": "legacy_quota_proxy"
        }

        # 整体状态
        if not gateway_running and not workbench_running:
            status["status"] = "unhealthy"
        elif not gateway_running or not workbench_running:
            status["status"] = "degraded"

        return status

    def log_message(self, format, *args):
        pass  # 减少日志噪音

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 13146
    server = HTTPServer(('127.0.0.1', port), HealthHandler)
    print(f"Health server running on port {port}")
    server.serve_forever()
PYTHON_SCRIPT

    python3 /tmp/health-server.py "$PORT" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"

    local attempt
    for attempt in $(seq 1 30); do
        if curl -s "http://127.0.0.1:$PORT/health" > /dev/null 2>&1; then
            echo "✅ 健康检查服务已启动 (端口 $PORT)"
            echo "   端点: http://127.0.0.1:$PORT/health"
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 0.2
    done

    if curl -s "http://127.0.0.1:$PORT/health" > /dev/null 2>&1; then
        echo "✅ 健康检查服务已启动 (端口 $PORT)"
        echo "   端点: http://127.0.0.1:$PORT/health"
    else
        echo "❌ 健康检查服务启动失败"
        return 1
    fi
}

stop_server() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo "✅ 健康检查服务已停止"
        fi
        rm -f "$PID_FILE"
    fi
    pkill -f "health-server.py" 2>/dev/null || true
}

status_server() {
    if pgrep -f "health-server.py" > /dev/null 2>&1; then
        echo "✅ 健康检查服务运行中 (端口 $PORT)"
        if command -v curl > /dev/null 2>&1; then
            echo ""
            curl -s "http://127.0.0.1:$PORT/health" | python3 -m json.tool 2>/dev/null || echo "无法获取健康状态"
        fi
    else
        echo "❌ 健康检查服务未运行"
    fi
}

case "${1:-start}" in
    start)   start_server ;;
    stop)    stop_server ;;
    restart) stop_server; sleep 1; start_server ;;
    status)  status_server ;;
    *)
        echo "用法: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
