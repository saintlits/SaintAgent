#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# update.sh - SaintAgent 依赖更新 & 项目同步
# =============================================================================
# 用法:
#   ./scripts/update.sh               # 更新所有组件依赖
#   ./scripts/update.sh --lucinate    # 仅更新 Lucinate (Go deps)
#   ./scripts/update.sh --genericagent # 仅更新 GenericAgent (Python deps)
#   ./scripts/update.sh --openwarp    # 仅更新 OpenWarp (Rust deps)
#   ./scripts/update.sh --check       # 仅检查更新（不安装）
# =============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

update_lucinate() {
  echo -e "${BLUE}━━━ Lucinate (Go) ━━━${NC}"
  local dir="$ROOT/lucinate"
  if [ ! -d "$dir" ]; then
    echo -e "  ${YELLOW}⚠️  目录不存在${NC}"
    return
  fi
  if ! command -v go &>/dev/null; then
    echo -e "  ${YELLOW}⚠️  未安装 Go${NC}"
    return
  fi
  cd "$dir"
  echo -n "  go mod tidy..."
  go mod tidy 2>&1 | tail -3 >>"$LOG_DIR/update.log"
  echo -e " ${GREEN}✅${NC}"
  echo -n "  go vet..."
  go vet ./... 2>&1 | tail -3 >>"$LOG_DIR/update.log"
  echo -e " ${GREEN}✅${NC}"
  echo -e "  ${GREEN}✅ Lucinate 依赖更新完成${NC}"
}

update_genericagent() {
  echo -e "${BLUE}━━━ GenericAgent (Python) ━━━${NC}"
  local dir="$ROOT/genericagent"
  if [ ! -d "$dir" ]; then
    echo -e "  ${YELLOW}⚠️  目录不存在${NC}"
    return
  fi
  cd "$dir"

  if command -v uv &>/dev/null; then
    echo -n "  uv sync..."
    uv sync 2>&1 | tail -3 >>"$LOG_DIR/update.log"
    echo -e " ${GREEN}✅${NC}"
  elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ] || [ -f "requirements.txt" ]; then
    echo -n "  pip install (editable)..."
    pip install -e . 2>&1 | tail -3 >>"$LOG_DIR/update.log"
    echo -e " ${GREEN}✅${NC}"
  else
    echo -e "  ${YELLOW}⚠️  未找到依赖配置${NC}"
    return
  fi

  echo -e "  ${GREEN}✅ GenericAgent 依赖更新完成${NC}"
}

update_openwarp() {
  echo -e "${BLUE}━━━ OpenWarp (Rust) ━━━${NC}"
  local dir="$ROOT/openwarp"
  if [ ! -d "$dir" ]; then
    echo -e "  ${YELLOW}⚠️  目录不存在${NC}"
    return
  fi
  if ! command -v cargo &>/dev/null; then
    echo -e "  ${YELLOW}⚠️  未安装 cargo${NC}"
    return
  fi
  cd "$dir"
  echo -n "  cargo update..."
  cargo update 2>&1 | tail -5 >>"$LOG_DIR/update.log"
  echo -e " ${GREEN}✅${NC}"
  echo -e "  ${GREEN}✅ OpenWarp 依赖更新完成${NC}"
}

show_help() {
  echo "用法: $0 [选项]"
  echo ""
  echo "选项:"
  echo "  (无参数)        更新所有组件依赖"
  echo "  --lucinate      仅 Lucinate"
  echo "  --genericagent  仅 GenericAgent"
  echo "  --openwarp      仅 OpenWarp"
  echo "  --check         仅检查（不实际更新）"
  echo "  --help          显示此帮助"
}

case "${1:-}" in
  --help|-h)       show_help ;;
  --lucinate)      update_lucinate ;;
  --genericagent)  update_genericagent ;;
  --openwarp)      update_openwarp ;;
  ""|--all)
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BOLD}  SaintAgent 依赖更新${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    update_lucinate
    echo ""
    update_genericagent
    echo ""
    update_openwarp
    echo ""
    echo -e "${GREEN}✅ 所有组件更新完成${NC}"
    echo "  日志: $LOG_DIR/update.log"
    ;;
  --check)
    echo "检查模式下不做实际操作。查看当前依赖:"
    echo ""
    [ -f "$ROOT/lucinate/go.mod" ] && echo "  Lucinate:     $ROOT/lucinate/go.mod"
    [ -f "$ROOT/genericagent/pyproject.toml" ] && echo "  GenericAgent: $ROOT/genericagent/pyproject.toml"
    [ -f "$ROOT/genericagent/requirements.txt" ] && echo "  GenericAgent: $ROOT/genericagent/requirements.txt"
    [ -f "$ROOT/openwarp/Cargo.toml" ] && echo "  OpenWarp:     $ROOT/openwarp/Cargo.toml"
    ;;
  *)
    echo "未知参数: $1"
    show_help
    exit 1
    ;;
esac
