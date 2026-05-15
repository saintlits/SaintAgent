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
echo ""
echo "=== 集成启动（推荐） ==="
echo "  一键启动（GA 服务 + Lucinate TUI）:"
echo "    ./scripts/run.sh"
echo "  附带编辑器:"
echo "    ./scripts/run.sh --openwarp"
echo "  单独启动服务:"
echo "    ./scripts/serve.sh"
echo "  启动 Lucinate TUI（连到 GA 后端）:"
echo "    ./scripts/chat.sh"
echo "  启动 OpenWarp 编辑器:"
echo "    ./scripts/openwarp.sh [目标]"
echo ""
echo "=== 组件状态 ==="
echo "  Lucinate:     $LUCINATE_BIN"
echo "  GenericAgent: $ROOT/genericagent"
echo "  OpenWarp:     $ROOT/openwarp"
echo "  Config:       $ROOT/openwarp-config"
echo ""
echo "单独启动组件（调试用）:"
echo "  Lucinate TUI:  $ROOT/lucinate/lucinate"
echo "  GA 交互式:     cd $ROOT/genericagent && python ga.py"
