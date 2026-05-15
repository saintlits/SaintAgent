#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== SaintAgent 一键构建 ==="

# 1. Lucinate (Go)
echo ""
echo "--- Lucinate ---"
cd "$ROOT/lucinate"
go mod tidy
go build -o lucinate ./cmd/lucinate/
echo "✅ Lucinate 构建完成: $ROOT/lucinate/lucinate"

# 2. GenericAgent (Python)
echo ""
echo "--- GenericAgent ---"
cd "$ROOT/genericagent"
if [ -f "pyproject.toml" ]; then
    uv sync 2>/dev/null || pip install -e . 2>/dev/null || echo "(跳过 Python deps)"
fi
echo "✅ GenericAgent 就绪"

# 3. OpenWarp (Rust)
echo ""
echo "--- OpenWarp ---"
cd "$ROOT/openwarp"
if command -v cargo &>/dev/null; then
    cargo build 2>&1 | tail -5
    echo "✅ OpenWarp 构建完成"
else
    echo "⚠️  cargo 未安装，跳过 OpenWarp 编译"
fi

echo ""
echo "=== SaintAgent 全部构建完成 ==="
