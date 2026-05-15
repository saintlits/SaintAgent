#!/bin/bash
# 启动 lucinate TUI 连接 GenericAgent HTTP Server
export LUCINATE_OPENAI_BASE_URL=http://127.0.0.1:8080/v1
export LUCINATE_OPENAI_DEFAULT_MODEL=genericagent

# 先确认 GA server 在运行
if ! curl -sf http://127.0.0.1:8080/health >/dev/null 2>&1; then
    echo "GA HTTP Server not running! Start it first:"
    echo "  cd /Users/Shared/code/app/GenericAgent && python3 ga_http_server.py --rtk &"
    echo "  或简写: gas"
    exit 1
fi

echo "Starting lucinate (GA TUI)..."
echo "  Backend: $LUCINATE_OPENAI_BASE_URL"
echo "  Model: $LUCINATE_OPENAI_DEFAULT_MODEL"
echo ""
exec "$(dirname "$0")/lucinate" "$@"
