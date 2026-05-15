#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# chat.sh - 启动 Lucinate TUI，通过 GA HTTP Server 与 GenericAgent 对话
# =============================================================================
# 用法:
#   ./scripts/chat.sh               # 启动 + 自动连接 GA 服务
#   ./scripts/chat.sh --ga-only     # 只启动 GA 服务（不打开 TUI）
#   ./scripts/chat.sh --no-ga       # 启动 TUI 但不自动启动 GA
#   ./scripts/chat.sh --help        # 查看帮助
#
# 环境变量:
#   GA_HOST          GA 服务地址 (默认 127.0.0.1)
#   GA_PORT          GA 服务端口 (默认 8080)
#   LUCINATE_ARGS    传给 lucinate 的额外参数
# =============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LUCINATE_BIN="$ROOT/lucinate/lucinate"
GA_HOST="${GA_HOST:-127.0.0.1}"
GA_PORT="${GA_PORT:-8080}"
GA_URL="http://${GA_HOST}:${GA_PORT}/v1"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_help() {
  cat <<EOF
用法: ./scripts/chat.sh [选项]

选项:
  --ga-only    只启动 GenericAgent 服务（不打开 Lucinate TUI）
  --no-ga      启动 Lucinate TUI 但不自动启动 GA 服务
               （需要手动运行 ./scripts/serve.sh）
  --help       显示此帮助

环境变量:
  GA_HOST      GA 服务监听地址 (默认: 127.0.0.1)
  GA_PORT      GA 服务端口 (默认: 8080)
  LUCINATE_ARGS 传给 lucinate 的额外 CLI 参数

示例:
  # 启动完整对话体验
  ./scripts/chat.sh

  # 只启动 GA 服务（后台）
  ./scripts/chat.sh --ga-only

  # 使用自定义端口
  GA_PORT=9090 ./scripts/chat.sh
EOF
  exit 0
}

# 解析参数
START_GA=true
START_TUI=true
for arg in "$@"; do
  case "$arg" in
    --help) show_help ;;
    --ga-only) START_TUI=false ;;
    --no-ga) START_GA=false ;;
    *)
      echo "未知参数: $arg"
      show_help
      ;;
  esac
done

# 检查 lucinate 二进制
if [ "$START_TUI" = true ]; then
  if [ ! -x "$LUCINATE_BIN" ]; then
    echo -e "${YELLOW}🔨 Lucinate 尚未编译，正在构建...${NC}"
    cd "$ROOT/lucinate"
    go build -o "$LUCINATE_BIN" ./cmd/lucinate/
    echo -e "${GREEN}✅ Lucinate 构建完成${NC}"
  fi
fi

# 启动 GA 服务
if [ "$START_GA" = true ]; then
  echo -e "${BLUE}🔌 启动 GenericAgent HTTP Server...${NC}"
  "$ROOT/scripts/serve.sh" --background 2>&1 | tail -5
fi

# 如果不启动 TUI，退出
if [ "$START_TUI" = false ]; then
  echo -e "${GREEN}✅ GA Server 已在后台运行${NC}"
  exit 0
fi

# 等待 GA 服务就绪（如果启动了）
if [ "$START_GA" = true ]; then
  echo -n "⏳ 等待后端就绪"
  for i in $(seq 1 10); do
    if curl -sf "http://${GA_HOST}:${GA_PORT}/health" >/dev/null 2>&1; then
      echo ""
      echo -e "${GREEN}✅ 后端就绪${NC}"
      break
    fi
    sleep 0.5
    echo -n "."
  done
fi

# 启动 Lucinate TUI（环境变量自动配置连接）
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🧠 SaintAgent — Lucinate + GenericAgent  ║${NC}"
echo -e "${GREEN}║   后端: ${GA_URL}${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# 设置 lucinate 环境变量
export LUCINATE_OPENAI_BASE_URL="$GA_URL"
export LUCINATE_OPENAI_API_KEY="genericagent"  # GA 忽略 API key，但 lucinate 需要非空

cd "$ROOT"
exec "$LUCINATE_BIN" ${LUCINATE_ARGS:-}
