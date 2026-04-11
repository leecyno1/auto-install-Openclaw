# PowerShell 脚本：OpenClaw Windows 环境检测与自动安装
# 用法: powershell -ExecutionPolicy Bypass -Command ". \install.ps1"

param(
    [switch]$AutoConfirmAll = $false,
    [switch]$Help = $false
)

# ================================ 颜色定义 ================================
$Colors = @{
    Green  = 'Green'
    Red    = 'Red'
    Yellow = 'Yellow'
    Cyan   = 'Cyan'
    Gray   = 'Gray'
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = 'Cyan')
    Write-Host $Message -ForegroundColor $Color
}

function Write-Header {
    Write-Host ""
    Write-ColorOutput "╔════════════════════════════════════════════════════════════════════╗" Cyan
    Write-ColorOutput "║  🦞 OpenClaw Windows 环境检测与安装工具                            ║" Cyan
    Write-ColorOutput "║  自动安装 WSL2 或 Git Bash 支持环境                                ║" Cyan
    Write-ColorOutput "╚════════════════════════════════════════════════════════════════════╝" Cyan
    Write-Host ""
}

if ($Help) {
    Write-Header
    Write-Host "参数:"
    Write-Host "  -AutoConfirmAll   自动确认所有提示"
    Write-Host "  -Help             显示帮助"
    exit 0
}

Write-Header

# ================================ 权限检查 ================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-ColorOutput "⚠️  需要管理员权限。请以管理员身份重新运行。" Yellow
    Write-Host "  右键点击 PowerShell 选择 '以管理员身份运行'"
    exit 1
}

# ================================ 环境检测 ================================
Write-ColorOutput "[检查] 操作系统版本..." Cyan
$osVersion = [System.Environment]::OSVersion
Write-ColorOutput "✓ 检测到 Windows" Green

Write-Host ""
Write-ColorOutput "[检查] WSL2 环境..." Cyan

$wslList = & wsl --list --verbose 2>$null
if ($wslList -match 2) {
    Write-ColorOutput "✓ WSL2 已安装" Green
    Write-Host "运行以下命令启动 OpenClaw 安装："
    Write-Host "  wsl bash -c 'curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash'"
    exit 0
}

Write-ColorOutput "✗ 未检测到 WSL2" Yellow

Write-Host ""
Write-ColorOutput "[检查] Git Bash 环境..." Cyan

if (Test-Path "C:\Program Files\Git\bin\bash.exe") {
    Write-ColorOutput "✓ Git Bash 已安装" Green
    Write-Host "运行以下命令启动 OpenClaw 安装："
    Write-Host "  & 'C:\Program Files\Git\bin\bash.exe' -c 'curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash'"
    exit 0
}

# ================================ 提示安装 ================================
Write-Host ""
Write-ColorOutput "❌ 未检测到任何 bash 环境" Red
Write-Host ""
Write-ColorOutput "请选择安装方案：" Yellow
Write-Host "  [A] WSL2 (推荐 - 完整 Linux 环境)"
Write-Host "  [B] Git Bash (快速 - 轻量级)"
Write-Host ""

if ($AutoConfirmAll) {
    $choice = "A"
} else {
    $choice = Read-Host "请输入选择 (A/B)"
}

switch ($choice.ToUpper()) {
    "A" {
        Write-ColorOutput "正在安装 WSL2..." Cyan
        Write-Host "执行: wsl --install -d Ubuntu"
        & wsl --install -d Ubuntu
    }
    "B" {
        Write-ColorOutput "请访问 https://git-scm.com/download/win 下载并安装 Git" Cyan
    }
    default {
        Write-ColorOutput "取消" Red
        exit 1
    }
}
