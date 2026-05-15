#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# logs.sh - SaintAgent 统一日志查看器
# =============================================================================
# 用法:
#   ./scripts/logs.sh                  # 查看 GA Server 日志 (tail -30)
#   ./scripts/logs.sh --ga             # （同上）
#   ./scripts/logs.sh --build          # 查看构建日志
#   ./scripts/logs.sh --all            # 查看所有日志
#   ./scripts/logs.sh --follow         # 持续跟踪 GA Server 日志
#   ./scripts/logs.sh --clear          # 清空日志
# =============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$ROOT/logs"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

mkdir -p "$LOG_DIR"

show_ga_log() {
  local log="$LOG_DIR/ga-server.log"
  if [ -f "$log" ]; then
    local size
    size=$(wc -l < "$log" | tr -d ' ')
    echo -e "${BLUE}📋 GA Server 日志${NC} ($size 行, $log)"
    echo "────────────────────────────────────────"
    if [ "${1:-}" = "--follow" ]; then
      tail -f "$log"
    else
      tail -30 "$log"
    fi
  else
    echo -e "${YELLOW}📋 GA Server 暂无日志${NC}"
    echo "   (启动后会生成: $LOG_DIR/ga-server.log)"
  fi
}

show_build_log() {
  local log="$LOG_DIR/build.log"
  if [ -f "$log" ]; then
    echo -e "${BLUE}📋 构建日志${NC} ($log)"
    echo "────────────────────────────────────────"
    tail -30 "$log"
  else
    echo -e "${YELLOW}📋 暂无构建日志${NC}"
  fi
}

clear_logs() {
  echo -e "${YELLOW}🧹 清空日志...${NC}"
  for f in "$LOG_DIR"/*.log; do
    if [ -f "$f" ]; then
      : > "$f"
      echo "  已清空: $f"
    fi
  done
  echo -e "${GREEN}✅ 完成${NC}"
}

show_all() {
  echo -e "${BLUE}════════════════════════════════${NC}"
  echo -e "${BOLD}  SaintAgent 日志总览${NC}"
  echo -e "${BLUE}════════════════════════════════${NC}"
  echo ""
  echo -e "${BLUE}--- GA Server ---${NC}"
  show_ga_log
  echo ""
  if [ -f "$LOG_DIR/build.log" ]; then
    echo -e "${BLUE}--- Build ---${NC}"
    show_build_log
  fi
  echo ""
  echo -e "日志目录: ${GREEN}$LOG_DIR${NC}"
  echo -e "查看全部: ${GREEN}ls -lh $LOG_DIR/${NC}"
}

case "${1:-}" in
  --ga|"")    show_ga_log "${2:-}" ;;
  --follow|-f) show_ga_log --follow ;;
  --build)    show_build_log ;;
  --all)      show_all ;;
  --clear)    clear_logs ;;
  --help|-h)
    echo "用法: $0 [--ga|--build|--all|--follow|--clear]"
    echo "  (无参数)   查看 GA Server 日志 (tail 30)"
    echo "  --follow    持续跟踪 GA Server 日志"
    echo "  --build     查看构建日志"
    echo "  --all       查看所有日志"
    echo "  --clear     清空日志"
    ;;
  *)
    echo "未知参数: $1"
    echo "用法: $0 [--ga|--build|--all|--follow|--clear]"
    exit 1
    ;;
esac
