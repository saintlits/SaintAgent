#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# run.sh - SaintAgent 一键启动
# =============================================================================
# 整合三件套：GenericAgent (后端) + Lucinate (前端) + OpenWarp (编辑)
#
# 用法:
#   ./scripts/run.sh                  # 启动 GA 服务 + Lucinate TUI
#   ./scripts/run.sh --openwarp       # 启动 GA + Lucinate + OpenWarp
#   ./scripts/run.sh --openwarp <dir> # 同上，用 OpenWarp 打开指定目录
#   ./scripts/run.sh --serve-only     # 只启动后台服务
#   ./scripts/run.sh --status         # 查看各服务状态
#   ./scripts/run.sh --stop           # 停止所有服务
#   ./scripts/run.sh --help           # 帮助
#
# 环境变量:
#   GA_HOST   GA 服务地址 (默认 127.0.0.1)
#   GA_PORT   GA 服务端口 (默认 8080)
#   OW_DIR    OpenWarp 打开的目录 (默认 .)
# =============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GA_HOST="${GA_HOST:-127.0.0.1}"
GA_PORT="${GA_PORT:-8080}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║  ${BOLD}🐧 SaintAgent — 智能开发助手${NC}               ${BLUE}║${NC}"
  echo -e "${BLUE}║${NC}                                              ${BLUE}║${NC}"
  echo -e "${BLUE}║${NC}  ${GREEN}GenericAgent${NC}  🤖   AI Agent 引擎        ${BLUE}║${NC}"
  echo -e "${BLUE}║${NC}  ${GREEN}Lucinate${NC}       💬   终端聊天界面        ${BLUE}║${NC}"
  echo -e "${BLUE}║${NC}  ${GREEN}OpenWarp${NC}       ✏️    代码编辑器          ${BLUE}║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
  echo ""
}

show_help() {
  banner
  echo "用法: ./scripts/run.sh [选项]"
  echo ""
  echo "选项:"
  echo "  (无参数)        启动 GA 服务 + Lucinate TUI"
  echo "  --openwarp [目录] 启动 GA + Lucinate TUI + OpenWarp 编辑器"
  echo "  --serve-only    仅启动后台服务（不打开 TUI）"
  echo "  --status        查看所有服务状态"
  echo "  --stop          停止所有服务"
  echo "  --help          显示此帮助"
  echo ""
  echo "示例:"
  echo "  ./scripts/run.sh                      # 标准模式"
  echo "  ./scripts/run.sh --openwarp ./lucinate # 顺便用 OpenWarp 编辑 lucinate"
  echo "  ./scripts/run.sh --status             # 检查状态"
  exit 0
}

# === 状态检查 ===
check_status() {
  echo -e "${BLUE}═══ SaintAgent 服务状态 ═══${NC}"
  echo ""
  "$ROOT/scripts/serve.sh" --status
  echo ""
  # 检查 lucinate 二进制
  if [ -x "$ROOT/lucinate/lucinate" ]; then
    LUC_VER=$("$ROOT/lucinate/lucinate" --version 2>/dev/null || echo "无法获取版本")
    echo -e "📦 Lucinate:    ${GREEN}已编译${NC} ($LUC_VER)"
  else
    echo -e "📦 Lucinate:    ${YELLOW}未编译${NC}（运行 build.sh 或 run.sh 自动编译）"
  fi
  # 检查 OpenWarp
  OW_BIN=$(find "$ROOT/openwarp/target" -name "warp-oss" -o -name "warp" -o -name "openwarp" 2>/dev/null | head -1)
  if [ -n "$OW_BIN" ]; then
    echo -e "📦 OpenWarp:    ${GREEN}已编译${NC} ($OW_BIN)"
  else
    echo -e "📦 OpenWarp:    ${YELLOW}未编译${NC}"
  fi
  # 检查 mykey
  if [ -f "$ROOT/genericagent/mykey.py" ]; then
    echo -e "🔑 API 密钥:    ${GREEN}已配置${NC}"
  else
    echo -e "🔑 API 密钥:    ${RED}缺失${NC}"
  fi
  echo ""
}

# === 停止所有 ===
stop_all() {
  echo "⏹️  停止所有 SaintAgent 服务..."
  "$ROOT/scripts/serve.sh" --stop
  echo "✅ 已停止"
  exit 0
}

# === 解析参数 ===
MODE="standard"
OW_TARGET=""
case "${1:-}" in
  --help|-h) show_help ;;
  --status) check_status; exit 0 ;;
  --stop) stop_all ;;
  --serve-only) MODE="serve-only" ;;
  --openwarp)
    MODE="openwarp"
    OW_TARGET="${2:-.}"
    ;;
  "") ;; # 默认模式
  *)
    echo "未知参数: $1"
    show_help
    ;;
esac

# === 前置检查 ===
if [ ! -f "$ROOT/genericagent/mykey.py" ]; then
  echo -e "${RED}❌ 缺少 API 密钥配置${NC}"
  echo "   需要创建软链接到原项目的 mykey.py:"
  echo "   ln -s /path/to/original/mykey.py $ROOT/genericagent/mykey.py"
  exit 1
fi

# 确保 logs 目录
mkdir -p "$ROOT/logs"

# === 打印横幅 ===
banner

# === 编译检查 ===
LUCINATE_BIN="$ROOT/lucinate/lucinate"
if [ ! -x "$LUCINATE_BIN" ]; then
  echo -e "${YELLOW}🔨 Lucinate 尚未编译，正在构建...${NC}"
  cd "$ROOT/lucinate"
  go build -o "$LUCINATE_BIN" ./cmd/lucinate/
  echo -e "${GREEN}✅ Lucinate 构建完成${NC}"
fi

# === 启动 GA 服务 ===
echo -e "${BLUE}🔌 启动 GenericAgent HTTP Server...${NC}"
"$ROOT/scripts/serve.sh" --background 2>&1 | tail -3 || {
  echo -e "${RED}❌ 启动 GA 服务失败，请检查日志:${NC}"
  echo "   tail -20 $ROOT/logs/ga-server.log"
  exit 1
}

# === 可选启动 OpenWarp ===
OW_PID=""
if [ "$MODE" = "openwarp" ]; then
  echo -e "${BLUE}✏️  启动 OpenWarp 编辑器...${NC}"
  cd "$ROOT/openwarp"
  OW_TARGET_ABS=$(cd "$ROOT/$OW_TARGET" 2>/dev/null && pwd || echo "$ROOT")
  
  # 尝试多种可能的 OpenWarp 二进制名称
  OW_BIN=""
  for candidate in "$ROOT/openwarp/target/release/warp-oss" "$ROOT/openwarp/target/debug/warp-oss" "$ROOT/openwarp/target/release/openwarp" "$ROOT/openwarp/target/debug/openwarp"; do
    if [ -x "$candidate" ]; then
      OW_BIN="$candidate"
      break
    fi
  done
  
  if [ -n "$OW_BIN" ]; then
    echo "   打开: $OW_TARGET_ABS"
    "$OW_BIN" "$OW_TARGET_ABS" &
    OW_PID=$!
    echo -e "${GREEN}✅ OpenWarp 已启动 (PID $OW_PID)${NC}"
  else
    echo -e "${YELLOW}⚠️  OpenWarp 未编译，跳过（先运行 scripts/build.sh）${NC}"
  fi
fi

# === 仅服务模式 ===
if [ "$MODE" = "serve-only" ]; then
  echo ""
  echo -e "${GREEN}✅ GA Server 已在后台运行 (PID $(cat "${TMPDIR:-/tmp}/genericagent-server.pid" 2>/dev/null || echo "?"))${NC}"
  echo "   健康检查: curl http://${GA_HOST}:${GA_PORT}/health"
  echo "   停止服务: ./scripts/run.sh --stop"
  exit 0
fi

# === 等待 GA 就绪 ===
echo -n "⏳ 等待后端就绪"
for i in $(seq 1 15); do
  if curl -sf "http://${GA_HOST}:${GA_PORT}/health" >/dev/null 2>&1; then
    echo ""
    echo -e "${GREEN}✅ 后端就绪${NC}"
    break
  fi
  sleep 0.5
  echo -n "."
done

# === 启动 Lucinate TUI ===
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🧠 SaintAgent — 进入对话                  ║${NC}"
echo -e "${GREEN}║   后端:  http://${GA_HOST}:${GA_PORT}/v1       ${NC}"
echo -e "${GREEN}║   退出 TUI 后自动停止服务                      ${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""

export LUCINATE_OPENAI_BASE_URL="http://${GA_HOST}:${GA_PORT}/v1"
export LUCINATE_OPENAI_API_KEY="genericagent"

cd "$ROOT"
set +e  # 允许 TUI 退出后继续执行
"$LUCINATE_BIN" ${LUCINATE_ARGS:-}
TUI_EXIT=$?
set -e

# === 清理 ===
echo ""
echo -e "${BLUE}🧹 清理服务...${NC}"

if [ -n "$OW_PID" ]; then
  kill "$OW_PID" 2>/dev/null || true
fi

"$ROOT/scripts/serve.sh" --stop

echo -e "${GREEN}✅ SaintAgent 已停止 (TUI 退出码: $TUI_EXIT)${NC}"
exit $TUI_EXIT
