#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# openwarp.sh - 启动 OpenWarp 编辑器（集成到 SaintAgent 工作流）
# =============================================================================
# 用法:
#   ./scripts/openwarp.sh [目录|文件]    # 打开指定路径
#   ./scripts/openwarp.sh               # 打开当前项目
#   ./scripts/openwarp.sh --wait        # 启动并等待退出（用于 Git 编辑器等）
#   ./scripts/openwarp.sh --build       # 先构建再启动
# =============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 查找 OpenWarp 二进制
OW_BIN=""
for candidate in \
  "$ROOT/openwarp/target/release/warp-oss" \
  "$ROOT/openwarp/target/debug/warp-oss" \
  "$ROOT/openwarp/target/release/openwarp" \
  "$ROOT/openwarp/target/debug/openwarp" \
  "$ROOT/openwarp/target/release/warp" \
  "$ROOT/openwarp/target/debug/warp"; do
  if [ -x "$candidate" ]; then
    OW_BIN="$candidate"
    break
  fi
done

# 处理参数
MODE="background"
TARGET=""

for arg in "$@"; do
  case "$arg" in
    --build) MODE="build";;
    --wait)  MODE="foreground";;
    --help|-h)
      echo "用法: $0 [--build|--wait] [目录|文件]"
      echo "  --build   先构建再启动"
      echo "  --wait    前台等待退出"
      exit 0
      ;;
    *)
      if [ -z "$TARGET" ]; then
        TARGET="$arg"
      fi
      ;;
  esac
done

if [ -z "$TARGET" ]; then
  TARGET="$ROOT"
fi

# 构建模式
if [ "$MODE" = "build" ] || [ ! -x "$OW_BIN" ]; then
  echo "🔨 构建 OpenWarp..."
  cd "$ROOT/openwarp"
  cargo build -p app 2>&1 | tail -5
  # 重新查找
  OW_BIN="$ROOT/openwarp/target/debug/warp-oss"
  if [ ! -x "$OW_BIN" ]; then
    OW_BIN="$ROOT/openwarp/target/debug/openwarp"
  fi
  if [ ! -x "$OW_BIN" ]; then
    echo "❌ OpenWarp 构建失败或未找到二进制"
    exit 1
  fi
  echo "✅ 构建完成: $OW_BIN"
fi

if [ ! -x "$OW_BIN" ]; then
  echo "❌ OpenWarp 未编译。先运行: scripts/build.sh"
  exit 1
fi

echo -e "\033[0;32m✏️  启动 OpenWarp:\033[0m $TARGET"
echo "   二进制: $OW_BIN"
echo ""

# 解析目标为绝对路径
TARGET_ABS=$(cd "$TARGET" 2>/dev/null && pwd || echo "$ROOT/$TARGET")

case "$MODE" in
  foreground)
    exec "$OW_BIN" "$TARGET_ABS"
    ;;
  background|*)
    "$OW_BIN" "$TARGET_ABS" &
    OW_PID=$!
    echo -e "\033[0;32m✅ OpenWarp 已启动 (PID $OW_PID)\033[0m"
    echo "   前台执行: fg %1"
    ;;
esac
