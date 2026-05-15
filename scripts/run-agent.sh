#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# run-agent.sh - SaintAgent 一键启动（专注 Agent 工作流）
# =============================================================================
# 整合三件套：GenericAgent (推理引擎) + Lucinate (AI 聊天 TUI) + OpenWarp (编辑)
#
# 用法:
#   ./scripts/run-agent.sh                   # 标准模式：GA 服务 + Lucinate TUI
#   ./scripts/run-agent.sh --openwarp        # 附加 OpenWarp 编辑器
#   ./scripts/run-agent.sh --serve-only      # 仅启动 GA 后端服务
#   ./scripts/run-agent.sh --status          # 查看状态
#   ./scripts/run-agent.sh --stop            # 停止所有
#
# 环境变量:
#   GA_HOST   GA 服务监听地址 (默认 127.0.0.1)
#   GA_PORT   GA 服务端口 (默认 8080)
# =============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GA_HOST="${GA_HOST:-127.0.0.1}"
GA_PORT="${GA_PORT:-8080}"
GA_URL="http://${GA_HOST}:${GA_PORT}"

# ── 色彩 ──
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

banner() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║  ${BOLD}🐧 SaintAgent — Agent 工作流${NC}                ${BLUE}║${NC}"
  echo -e "${BLUE}╠══════════════════════════════════════════════╣${NC}"
  echo -e "${BLUE}║${NC}  ${GREEN}GenericAgent${NC}  🤖   AI 推理引擎            ${BLUE}║${NC}"
  echo -e "${BLUE}║${NC}  ${GREEN}Lucinate${NC}       💬   AI 聊天 TUI           ${BLUE}║${NC}"
  echo -e "${BLUE}║${NC}  ${GREEN}OpenWarp${NC}       ✏️   代码编辑器            ${BLUE}║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
  echo ""
}

show_help() {
  banner
  echo "用法: $0 [选项]"
  echo ""
  echo "选项:"
  echo "  (无参数)        启动 GA 服务 + Lucinate TUI"
  echo "  --openwarp [目录] 启动 GA + Lucinate + OpenWarp"
  echo "  --serve-only    仅启动 GA 后端服务（无 TUI）"
  echo "  --status        查看所有服务状态"
  echo "  --stop          停止所有服务"
  echo "  --logs          查看后端日志"
  echo "  --help          显示此帮助"
  echo ""
  echo "示例:"
  echo "  $0                         # 标准 Agent 模式"
  echo "  $0 --openwarp              # 带编辑器"
  echo "  $0 --openwarp ./lucinate   # 编辑 lucinate 目录"
  echo "  $0 --status                # 检查状态"
  echo ""
  echo "环境变量:"
  echo "  GA_HOST=0.0.0.0 GA_PORT=9090 $0"
  exit 0
}

# ── 检查依赖 ──
check_deps() {
  local missing=0
  for cmd in python3 curl; do
    if ! command -v "$cmd" &>/dev/null; then
      echo -e "${RED}❌ 未找到 $cmd${NC}"
      missing=1
    fi
  done
  if [ $missing -eq 1 ]; then
    echo "请安装缺失的依赖"
    exit 1
  fi
}

# ── 确保 mykey 存在 ──
check_mykey() {
  if [ ! -f "$ROOT/genericagent/mykey.py" ]; then
    echo -e "${YELLOW}⚠️  未找到 mykey.py${NC}"
    echo "   请从原项目复制或创建符号链接:"
    echo "   ln -s /path/to/original/mykey.py $ROOT/genericagent/mykey.py"
    echo ""
    echo -e "${YELLOW}   或者从模板创建:${NC}"
    echo "   cp $ROOT/genericagent/mykey_template.py $ROOT/genericagent/mykey.py"
    echo "   # 然后编辑 mykey.py 填入 API 密钥"
    exit 1
  fi
}

# ── 确保 Lucinate 已编译 ──
ensure_lucinate() {
  local bin="$ROOT/lucinate/lucinate"
  if [ ! -x "$bin" ]; then
    echo -e "${YELLOW}🔨 Lucinate 未编译，正在构建...${NC}"
    cd "$ROOT/lucinate"
    if ! command -v go &>/dev/null; then
      echo -e "${RED}❌ 未安装 Go${NC}"
      exit 1
    fi
    go build -o "$bin" ./cmd/lucinate/
    echo -e "${GREEN}✅ Lucinate 构建完成${NC}"
  fi
}

# ── 启动 GA 服务 ──
start_ga() {
  "$ROOT/scripts/serve.sh" --background 2>&1 | tail -3
}

# ── 启动 Lucinate TUI ──
start_lucinate() {
  local bin="$ROOT/lucinate/lucinate"
  local ga_url="http://${GA_HOST}:${GA_PORT}/v1"

  echo -e "${BLUE}💬 启动 Lucinate TUI...${NC}"
  echo -e "   后端: ${GREEN}${ga_url}${NC}"
  echo ""

  # 设置环境变量让 lucinate 连到 GA
  export LUCINATE_OPENAI_BASE_URL="$ga_url"
  export LUCINATE_OPENAI_DEFAULT_MODEL="genericagent"

  exec "$bin" "$@"
}

# ── 启动 OpenWarp ──
start_openwarp() {
  local target="${1:-$ROOT}"
  if [ -x "$ROOT/scripts/openwarp.sh" ]; then
    "$ROOT/scripts/openwarp.sh" "$target"
  else
    echo -e "${YELLOW}⚠️  openwarp.sh 未找到，跳过${NC}"
  fi
}

# ── 状态 ──
show_status() {
  echo -e "${BLUE}═══ SaintAgent 状态 ═══${NC}"
  echo ""
  "$ROOT/scripts/serve.sh" --status 2>/dev/null || echo -e "${YELLOW}⚠️  状态检查失败${NC}"

  echo ""
  if [ -x "$ROOT/lucinate/lucinate" ]; then
    echo -e "📦 Lucinate:    ${GREEN}已编译${NC}"
  else
    echo -e "📦 Lucinate:    ${YELLOW}未编译${NC}"
  fi

  local ow_bin
  ow_bin=$(find "$ROOT/openwarp/target" -name "warp-oss" -o -name "openwarp" 2>/dev/null | head -1)
  if [ -n "$ow_bin" ]; then
    echo -e "📦 OpenWarp:    ${GREEN}已编译${NC}"
  else
    echo -e "📦 OpenWarp:    ${YELLOW}未编译${NC}"
  fi

  if [ -f "$ROOT/genericagent/mykey.py" ]; then
    echo -e "🔑 API 密钥:    ${GREEN}已配置${NC}"
  else
    echo -e "🔑 API 密钥:    ${RED}缺失${NC}"
  fi
  echo ""
}

# ── 停止 ──
stop_all() {
  echo "⏹️  停止 SaintAgent 服务..."
  "$ROOT/scripts/serve.sh" --stop 2>/dev/null || true
  echo "✅ 已停止"
  exit 0
}

# ── 查看日志 ──
show_logs() {
  local log="$ROOT/logs/ga-server.log"
  if [ -f "$log" ]; then
    echo -e "${BLUE}📋 GA Server 日志 (tail -30):${NC}"
    tail -30 "$log"
    echo ""
    echo "持续查看: tail -f $log"
  else
    echo -e "${YELLOW}📋 暂无日志文件${NC}"
  fi
}

# ============================================================
# 主流程
# ============================================================

# 解析参数
MODE="standard"
OW_TARGET=""
for arg in "$@"; do
  case "$arg" in
    --help|-h) show_help ;;
    --serve-only) MODE="serve-only" ;;
    --status) MODE="status" ;;
    --stop) MODE="stop" ;;
    --logs) MODE="logs" ;;
    --openwarp) MODE="with-openwarp" ;;
    --*) echo "未知参数: $arg"; show_help ;;
    *)
      if [ "$MODE" = "with-openwarp" ] && [ -z "$OW_TARGET" ]; then
        OW_TARGET="$arg"
      else
        echo "未知参数: $arg"; show_help
      fi
      ;;
  esac
done

case "$MODE" in
  status)
    show_status
    exit 0
    ;;
  stop)
    stop_all
    ;;
  logs)
    show_logs
    exit 0
    ;;
esac

# 标准模式前置检查
banner
check_deps
check_mykey

if [ "$MODE" = "serve-only" ]; then
  start_ga
  exit 0
fi

# Standard / with-openwarp
ensure_lucinate
start_ga

# 如果带 OpenWarp，先启动（后台）
if [ "$MODE" = "with-openwarp" ]; then
  start_openwarp "${OW_TARGET:-$ROOT}"
fi

# 等待 GA 就绪
echo -n "⏳ 等待后端就绪"
for i in $(seq 1 15); do
  if curl -sf "${GA_URL}/health" >/dev/null 2>&1; then
    echo ""
    echo -e "${GREEN}✅ 后端就绪${NC}"
    break
  fi
  sleep 0.5
  echo -n "."
done

# 启动 Lucinate TUI（前台，替换当前进程）
start_lucinate
