#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# serve.sh - 启动 GenericAgent HTTP Server（lucinate 的后端引擎）
# =============================================================================
# 用法:
#   ./scripts/serve.sh              # 后台启动（默认）
#   ./scripts/serve.sh --foreground # 前台启动（可见日志）
#   ./scripts/serve.sh --stop       # 停止后台服务
#   ./scripts/serve.sh --status     # 查看状态
# =============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIDFILE="${TMPDIR:-/tmp}/genericagent-server.pid"
HOST="${GA_HOST:-127.0.0.1}"
PORT="${GA_PORT:-8080}"

# 确保 mykey.py 存在（API 密钥配置）
if [ ! -f "$ROOT/genericagent/mykey.py" ]; then
    echo "❌ 缺少 $ROOT/genericagent/mykey.py（API 密钥配置）"
    echo "   请从原项目复制一份或创建软链接："
    echo "   ln -s /path/to/original/mykey.py $ROOT/genericagent/mykey.py"
    exit 1
fi

case "${1:-}" in
  --stop)
    if [ -f "$PIDFILE" ]; then
      PID=$(cat "$PIDFILE")
      if kill -0 "$PID" 2>/dev/null; then
        echo "⏹️  停止 GenericAgent Server (PID $PID)..."
        kill "$PID" 2>/dev/null || true
        sleep 1
        # 强制终止
        kill -9 "$PID" 2>/dev/null || true
      else
        echo "⚠️  PID $PID 不存在，清理 pidfile"
      fi
      rm -f "$PIDFILE"
    else
      echo "ℹ️  没有运行中的 GenericAgent Server"
    fi
    exit 0
    ;;

  --status)
    if [ -f "$PIDFILE" ]; then
      PID=$(cat "$PIDFILE")
      if kill -0 "$PID" 2>/dev/null; then
        echo "✅ GenericAgent Server 运行中 (PID $PID)"
        echo "   http://${HOST}:${PORT}/health"
        curl -sf "http://${HOST}:${PORT}/health" 2>/dev/null && echo "   (响应正常)" || echo "   (未响应)"
      else
        echo "⚠️  PID $PID 已不存在（上次异常退出？）"
        rm -f "$PIDFILE"
      fi
    else
      echo "ℹ️  GenericAgent Server 未运行"
    fi
    exit 0
    ;;

  --foreground)
    echo "🚀 GenericAgent Server (前台模式) http://${HOST}:${PORT}"
    cd "$ROOT/genericagent"
    exec python3 ga_http_server.py --host "$HOST" --port "$PORT"
    ;;

  ""|--background|--daemon)
    # 默认：后台启动
    if [ -f "$PIDFILE" ]; then
      PID=$(cat "$PIDFILE")
      if kill -0 "$PID" 2>/dev/null; then
        echo "✅ GenericAgent Server 已在运行 (PID $PID)"
        echo "   http://${HOST}:${PORT}"
        exit 0
      fi
      rm -f "$PIDFILE"
    fi

    echo "🚀 启动 GenericAgent Server (后台) http://${HOST}:${PORT}"
    cd "$ROOT/genericagent"
    nohup python3 ga_http_server.py --host "$HOST" --port "$PORT" \
      > "$ROOT/logs/ga-server.log" 2>&1 &
    PID=$!
    echo $PID > "$PIDFILE"

    # 等待服务就绪（最多 10 秒）
    echo -n "⏳ 等待服务就绪"
    for i in $(seq 1 20); do
      if curl -sf "http://${HOST}:${PORT}/health" >/dev/null 2>&1; then
        echo ""
        echo "✅ GenericAgent Server 启动成功 (PID $PID)"
        echo "   http://${HOST}:${PORT}/health ← 健康检查"
        echo "   http://${HOST}:${PORT}/v1/models ← 模型列表"
        echo "   ${ROOT}/logs/ga-server.log  ← 日志"
        exit 0
      fi
      sleep 0.5
      echo -n "."
    done
    echo ""
    echo "⚠️  服务未能在 10 秒内就绪，请检查日志:"
    echo "   tail -20 $ROOT/logs/ga-server.log"
    exit 1
    ;;

  *)
    echo "用法: $0 [--foreground|--stop|--status]"
    exit 1
    ;;
esac
