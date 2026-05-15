#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# test.sh - SaintAgent 跨组件测试运行器
# =============================================================================
# 用法:
#   ./scripts/test.sh                  # 运行所有测试
#   ./scripts/test.sh --lucinate       # 仅测试 Lucinate (Go)
#   ./scripts/test.sh --genericagent   # 仅测试 GenericAgent (Python)
#   ./scripts/test.sh --openwarp       # 仅测试 OpenWarp (Rust)
#   ./scripts/test.sh --quick          # 快速模式（只跑关键测试）
#   ./scripts/test.sh --list           # 列出所有测试
# =============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0
FAIL=0
SKIP=0
TIMINGS=()

record() {
  local name="$1" status="$2" duration="$3"
  TIMINGS+=("$name:$status:${duration}s")
  case "$status" in
    PASS) PASS=$((PASS + 1)) ;;
    FAIL) FAIL=$((FAIL + 1)) ;;
    SKIP) SKIP=$((SKIP + 1)) ;;
  esac
}

banner() {
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BOLD}  SaintAgent 测试套件${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo ""
}

summary() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BOLD}  测试结果汇总${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "  ${GREEN}通过: $PASS${NC}"
  echo -e "  ${RED}失败: $FAIL${NC}"
  echo -e "  ${YELLOW}跳过: $SKIP${NC}"
  echo -e "  ${BLUE}总计: $((PASS + FAIL + SKIP))${NC}"
  echo ""
  if [ $FAIL -gt 0 ]; then
    echo -e "  ${RED}❌ 有 $FAIL 个测试失败${NC}"
    return 1
  else
    echo -e "  ${GREEN}✅ 全部通过${NC}"
    return 0
  fi
}

# ── Lucinate (Go) ──
test_lucinate() {
  echo -e "${BLUE}━━━ Lucinate (Go) ━━━${NC}"
  local dir="$ROOT/lucinate"
  if [ ! -d "$dir" ]; then
    echo -e "  ${YELLOW}⚠️  目录不存在: $dir${NC}"
    record "lucinate" SKIP 0
    return
  fi
  if [ ! -f "$dir/go.mod" ]; then
    echo -e "  ${YELLOW}⚠️  不是 Go 项目 (无 go.mod)${NC}"
    record "lucinate" SKIP 0
    return
  fi

  local start
  start=$(date +%s)
  echo -n "  🧪 go vet..."
  if (cd "$dir" && go vet ./... 2>>"$LOG_DIR/test-lucinate.log"); then
    echo -e " ${GREEN}✅${NC}"
  else
    echo -e " ${RED}❌${NC}"
  fi

  echo -n "  🧪 go test..."
  if (cd "$dir" && go test ./... -count=1 -timeout 60s 2>&1 | tail -3 >>"$LOG_DIR/test-lucinate.log"); then
    echo -e " ${GREEN}✅${NC}"
    record "lucinate" PASS "$(($(date +%s) - start))"
  else
    echo -e " ${RED}❌${NC}"
    echo "     日志: tail -20 $LOG_DIR/test-lucinate.log"
    record "lucinate" FAIL "$(($(date +%s) - start))"
  fi
}

# ── GenericAgent (Python) ──
test_genericagent() {
  echo -e "${BLUE}━━━ GenericAgent (Python) ━━━${NC}"
  local dir="$ROOT/genericagent"
  if [ ! -d "$dir" ]; then
    echo -e "  ${YELLOW}⚠️  目录不存在: $dir${NC}"
    record "genericagent" SKIP 0
    return
  fi

  local start
  start=$(date +%s)

  # Python 语法检查
  echo -n "  🧪 syntax check..."
  if python3 -m py_compile "$dir/ga.py" 2>>"$LOG_DIR/test-ga.log"; then
    echo -e " ${GREEN}✅${NC}"
  else
    echo -e " ${RED}❌${NC}"
    record "genericagent" FAIL "$(($(date +%s) - start))"
    return
  fi

  # 检查关键模块能否导入
  echo -n "  🧪 module import..."
  if (cd "$dir" && python3 -c "
import sys
sys.path.insert(0, '.')
from agent_loop import BaseHandler, StepOutcome
print('  agent_loop OK')
" 2>>"$LOG_DIR/test-ga.log"); then
    echo -e " ${GREEN}✅${NC}"
  else
    echo -e " ${RED}❌${NC}"
    echo "     日志: tail -20 $LOG_DIR/test-ga.log"
    record "genericagent" FAIL "$(($(date +%s) - start))"
    return
  fi

  record "genericagent" PASS "$(($(date +%s) - start))"
}

# ── OpenWarp (Rust) ──
test_openwarp() {
  echo -e "${BLUE}━━━ OpenWarp (Rust) ━━━${NC}"
  local dir="$ROOT/openwarp"
  if [ ! -d "$dir" ]; then
    echo -e "  ${YELLOW}⚠️  目录不存在: $dir${NC}"
    record "openwarp" SKIP 0
    return
  fi
  if [ ! -f "$dir/Cargo.toml" ]; then
    echo -e "  ${YELLOW}⚠️  不是 Rust 项目 (无 Cargo.toml)${NC}"
    record "openwarp" SKIP 0
    return
  fi
  if ! command -v cargo &>/dev/null; then
    echo -e "  ${YELLOW}⚠️  未安装 cargo${NC}"
    record "openwarp" SKIP 0
    return
  fi

  local start
  start=$(date +%s)
  echo -n "  🧪 cargo check..."
  if (cd "$dir" && cargo check 2>&1 | tail -5 >>"$LOG_DIR/test-openwarp.log"); then
    echo -e " ${GREEN}✅${NC}"
  else
    echo -e " ${RED}❌${NC}"
    echo "     日志: tail -20 $LOG_DIR/test-openwarp.log"
    record "openwarp" FAIL "$(($(date +%s) - start))"
    return
  fi

  echo -n "  🧪 cargo test..."
  if (cd "$dir" && cargo test --quiet 2>&1 | tail -5 >>"$LOG_DIR/test-openwarp.log"); then
    echo -e " ${GREEN}✅${NC}"
    record "openwarp" PASS "$(($(date +%s) - start))"
  else
    echo -e " ${RED}❌${NC}"
    echo "     日志: tail -20 $LOG_DIR/test-openwarp.log"
    record "openwarp" FAIL "$(($(date +%s) - start))"
  fi
}

# ── 集成测试 ──
test_integration() {
  echo -e "${BLUE}━━━ 集成检查 ━━━${NC}"
  local start
  start=$(date +%s)

  # 检查 git 状态
  if cd "$ROOT" && git rev-parse --git-dir >/dev/null 2>&1; then
    echo -e "  📦 Git 仓库:     ${GREEN}✅${NC}"
  else
    echo -e "  📦 Git 仓库:     ${RED}❌ 未初始化${NC}"
  fi

  # 检查 mykey
  if [ -f "$ROOT/genericagent/mykey.py" ]; then
    echo -e "  🔑 API 密钥:     ${GREEN}✅${NC}"
  else
    echo -e "  🔑 API 密钥:     ${YELLOW}⚠️  未配置${NC}"
  fi

  # 检查各项目目录
  for proj in lucinate genericagent openwarp openwarp-config; do
    if [ -d "$ROOT/$proj" ]; then
      echo -e "  📁 $proj:    ${GREEN}✅${NC}"
    else
      echo -e "  📁 $proj:    ${RED}❌ 缺失${NC}"
    fi
  done

  record "integration" PASS "$(($(date +%s) - start))"
}

# ── 列出测试 ──
list_tests() {
  echo "可用测试:"
  grep -E '^test_\w+\(\)' "$0" | sed 's/test_//;s/()//' | while read -r t; do
    echo "  --$t"
  done
}

# ============================================================
# 主入口
# ============================================================

case "${1:-}" in
  --list)              list_tests; exit 0 ;;
  --lucinate|--go)     banner; test_lucinate; summary ;;
  --genericagent|--py) banner; test_genericagent; summary ;;
  --openwarp|--rust)   banner; test_openwarp; summary ;;
  --integration)       banner; test_integration; summary ;;
  --quick)
    banner
    test_lucinate
    test_genericagent
    test_integration
    summary
    ;;
  ""|--all|*)
    banner
    test_lucinate
    test_genericagent
    test_openwarp
    test_integration
    summary
    ;;
esac
