#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== SaintAgent Dev Environment ==="
echo ""

# 构建 Lucinate（如果不存在或强制重建）
LUCINATE_BIN="$ROOT/lucinate/lucinate"
if [ ! -x "$LUCINATE_BIN" ]; then
    echo "→ 构建 Lucinate..."
    cd "$ROOT/lucinate"
    go build -o lucinate ./cmd/lucinate/
fi

# 确保 GenericAgent 在 PYTHONPATH
export PYTHONPATH="$ROOT/genericagent:$PYTHONPATH"

echo "=== 组件就绪 ==="
echo "  Lucinate:     $LUCINATE_BIN"
echo "  GenericAgent: $ROOT/genericagent"
echo "  OpenWarp:     $ROOT/openwarp"
echo "  Config:       $ROOT/openwarp-config"
echo ""
echo "启动 Lucinate TUI:"
echo "  $ROOT/lucinate/lucinate"
echo ""
echo "启动 GenericAgent:"
echo "  cd $ROOT/genericagent && python ga.py"
