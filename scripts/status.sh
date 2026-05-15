#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# status.sh - SaintAgent 组件健康检查 & 系统信息
# =============================================================================
# 用法:
#   ./scripts/status.sh              # 完整状态
#   ./scripts/status.sh --short      # 精简输出（适合嵌入其他脚本）
#   ./scripts/status.sh --json       # JSON 格式（机器可读）
# =============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GA_HOST="${GA_HOST:-127.0.0.1}"
GA_PORT="${GA_PORT:-8080}"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

check_ga() {
  local pid_file="${TMPDIR:-/tmp}/genericagent-server.pid"
  local pid=""
  local running=false
  local healthy=false

  if [ -f "$pid_file" ]; then
    pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
      running=true
      if curl -sf "http://${GA_HOST}:${GA_PORT}/health" >/dev/null 2>&1; then
        healthy=true
      fi
    fi
  fi

  if [ "$running" = true ] && [ "$healthy" = true ]; then
    echo -e "  GenericAgent  ${GREEN}✅ 运行中${NC}  (PID $pid, http://${GA_HOST}:${GA_PORT})"
  elif [ "$running" = true ]; then
    echo -e "  GenericAgent  ${YELLOW}⚠️  进程存在但未响应${NC} (PID $pid)"
  else
    echo -e "  GenericAgent  ${RED}❌ 未运行${NC}"
  fi
}

check_lucinate() {
  local bin="$ROOT/lucinate/lucinate"
  if [ -x "$bin" ]; then
    local ver
    ver=$("$bin" --version 2>/dev/null || echo "?")
    echo -e "  Lucinate      ${GREEN}✅ 已编译${NC}  ($ver)"
  else
    echo -e "  Lucinate      ${YELLOW}⚠️  未编译${NC}  （运行 scripts/build.sh）"
  fi
}

check_openwarp() {
  local bin
  bin=$(find "$ROOT/openwarp/target" \( -name "warp-oss" -o -name "openwarp" \) -type f 2>/dev/null | head -1)
  if [ -n "$bin" ] && [ -x "$bin" ]; then
    echo -e "  OpenWarp      ${GREEN}✅ 已编译${NC}  ($bin)"
  else
    echo -e "  OpenWarp      ${YELLOW}⚠️  未编译${NC}  （运行 scripts/build.sh）"
  fi
}

check_mykey() {
  if [ -f "$ROOT/genericagent/mykey.py" ]; then
    echo -e "  API 密钥      ${GREEN}✅ 已配置${NC}"
  else
    echo -e "  API 密钥      ${RED}❌ 缺失${NC}"
  fi
}

check_git() {
  if cd "$ROOT" && git rev-parse --git-dir >/dev/null 2>&1; then
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    local hash
    hash=$(git rev-parse --short HEAD 2>/dev/null)
    local status
    status=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
    if [ "$status" -eq 0 ]; then
      echo -e "  Git           ${GREEN}✅ 干净${NC}  ($branch @ $hash)"
    else
      echo -e "  Git           ${YELLOW}⚠️  有 $status 个未提交${NC}  ($branch @ $hash)"
    fi
  else
    echo -e "  Git           ${RED}❌ 未初始化${NC}"
  fi
}

check_space() {
  local used
  used=$(cd "$ROOT" && du -sh .git 2>/dev/null | cut -f1 || echo "?")
  local total
  total=$(cd "$ROOT" && du -sh . 2>/dev/null | cut -f1 || echo "?")
  echo -e "  磁盘使用      ${BLUE}${total}${NC}  (.git: ${used})"
}

# ── 主逻辑 ──
case "${1:-}" in
  --short)
    check_ga | sed 's/\x1b\[[0-9;]*m//g' | head -1
    check_lucinate | sed 's/\x1b\[[0-9;]*m//g' | head -1
    check_openwarp | sed 's/\x1b\[[0-9;]*m//g' | head -1
    ;;
  --json)
    # 机器可读 JSON 输出
    local ga_running=false ga_healthy=false
    local pid_file="${TMPDIR:-/tmp}/genericagent-server.pid"
    if [ -f "$pid_file" ]; then
      pid=$(cat "$pid_file")
      if kill -0 "$pid" 2>/dev/null; then
        ga_running=true
        curl -sf "http://${GA_HOST}:${GA_PORT}/health" >/dev/null 2>&1 && ga_healthy=true
      fi
    fi
    local lucinate_built=false
    [ -x "$ROOT/lucinate/lucinate" ] && lucinate_built=true
    local openwarp_built=false
    find "$ROOT/openwarp/target" \( -name "warp-oss" -o -name "openwarp" \) -type f 2>/dev/null | head -1 | grep -q . && openwarp_built=true
    local mykey_ok=false
    [ -f "$ROOT/genericagent/mykey.py" ] && mykey_ok=true
    cat <<EOF
{
  "genericagent": { "running": $ga_running, "healthy": $ga_healthy, "url": "http://${GA_HOST}:${GA_PORT}" },
  "lucinate": { "built": $lucinate_built },
  "openwarp": { "built": $openwarp_built },
  "config": { "mykey": $mykey_ok }
}
EOF
    ;;
  ""|--pretty|*)
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BOLD}  SaintAgent 组件状态${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    check_ga
    check_lucinate
    check_openwarp
    check_mykey
    check_git
    check_space
    echo ""
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    echo -e "  快捷命令:"
    echo -e "    ${GREEN}./scripts/run-agent.sh${NC}       启动 Agent 工作流"
    echo -e "    ${GREEN}./scripts/build.sh${NC}           重新构建所有组件"
    echo -e "    ${GREEN}./scripts/logs.sh${NC}            查看日志"
    echo -e "    ${GREEN}tail -f logs/ga-server.log${NC}   实时日志"
    echo ""
    ;;
esac
