#!/usr/bin/env python3
"""
GA HTTP Server - 暴露 OpenAI-compatible /v1/chat/completions API
供 lucinate TUI 作为前端使用

架构:
  lucinate (Go TUI) → HTTP POST /v1/chat/completions → GA agent loop
  - stream=true: SSE streaming (chunk by chunk)
  - stream=false: full response

用法:
  python ga_http_server.py [--host 127.0.0.1] [--port 8080]
"""

import os, sys, json, time, uuid, re, threading, subprocess
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, StreamingResponse

# GA imports
GA_ROOT = Path(__file__).parent.resolve()
sys.path.insert(0, str(GA_ROOT))

from agentmain import (  # type: ignore
    GenericAgent, get_system_prompt, load_tool_schema,
)
from agent_loop import agent_runner_loop  # type: ignore
from ga import GenericAgentHandler, smart_format, format_error  # type: ignore

import uvicorn

# ── chunk 清理 ──
def format_chunk(chunk: str) -> str:
    if not chunk: return ""
    cleaned = re.sub(r'🛠️.*?\n', '', chunk)
    cleaned = re.sub(r'\n\nLLM Running \(Turn \d+\) \.\.\.\n\n', '\n', cleaned)
    cleaned = re.sub(r'\n{3,}', '\n\n', cleaned)
    cleaned = re.sub(r'`````\s*\n', '', cleaned)
    return cleaned.strip()


# ── Session 管理 ──
_session_store: dict = {}
_session_lock = threading.Lock()

def get_session(session_id: str):
    with _session_lock:
        if session_id not in _session_store:
            # 创建新 session: 使用 GA 的 handler 机制维护历史
            from ga import BaseHandler
            empty_history: list = []
            handler = GenericAgentHandler(
                parent=None,  # HTTP mode: no parent agent needed
                last_history=empty_history,
                cwd=str(GA_ROOT / 'temp')
            )
            _session_store[session_id] = {
                'handler': handler,
                'llmclient': None,  # 延迟初始化
            }
        return _session_store[session_id]


# ── FastAPI app ──
app = FastAPI(title="GenericAgent HTTP Server")


@app.on_event("startup")
async def startup():
    """初始化 GA agent"""
    # 初始化工具 schema
    load_tool_schema()
    print("[ga_http_server] GA agent initialized.")


@app.get("/health")
async def health():
    return {"status": "ok", "service": "genericagent"}


@app.get("/v1/models")
async def list_models():
    """OpenAI-compatible /v1/models endpoint - required by lucinate"""
    return {
        "object": "list",
        "data": [
            {
                "id": "genericagent",
                "object": "model",
                "created": int(time.time()),
                "owned_by": "ga"
            }
        ]
    }


@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    """OpenAI-compatible /v1/chat/completions endpoint"""
    try:
        body = await request.json()
    except Exception as e:
        return JSONResponse({"error": f"Invalid JSON: {e}"}, status_code=400)

    # 获取 messages 和 stream
    messages = body.get("messages", [])
    stream = body.get("stream", False)
    model = body.get("model", "genericagent")  # GA ignores this

    if not messages:
        return JSONResponse({"error": "messages is required"}, status_code=400)

    # 提取用户消息 (OpenAI format: messages is a list of {role, content})
    # 支持 system/user/assistant 角色，GA 只需要最新 user 消息 + 历史
    user_message = None
    for msg in reversed(messages):
        if msg.get("role") == "user":
            user_message = msg["content"]
            break

    if not user_message:
        return JSONResponse({"error": "No user message found"}, status_code=400)

    # 获取/创建 session
    session_id = body.get("session_id", "default")
    session = get_session(session_id)

    # 延迟初始化 llmclient (首次请求时加载 mykeys)
    if session['llmclient'] is None:
        agent = GenericAgent()
        session['llmclient'] = agent.llmclient
        session['agent'] = agent  # 保存 agent 作为 handler 的 parent

    llmclient = session['llmclient']
    handler = session['handler']

    # 确保 handler 有 parent 引用 (首次请求时设置)
    if handler.parent is None and session.get('agent'):
        handler.parent = session['agent']

    # 构建系统提示
    sys_prompt = get_system_prompt()

    # 调用 agent_runner_loop
    gen = agent_runner_loop(
        llmclient,
        sys_prompt,
        user_message,
        handler,
        load_tool_schema.__globals__.get('TOOLS_SCHEMA', []),  # type: ignore
        max_turns=70,
        verbose=False
    )

    if stream:
        # ── Stream 模式 ──
        # 使用同步生成器 → StreamingResponse 在线程池中运行，不阻塞事件循环
        def event_stream():
            try:
                for chunk in gen:
                    cleaned = format_chunk(chunk)
                    if cleaned:
                        yield f"data: {json.dumps({'id': f'chatcmpl-{uuid.uuid4().hex[:8]}', 'object': 'chat.completion.chunk', 'created': int(time.time()), 'model': model, 'choices': [{'index': 0, 'delta': {'content': cleaned}, 'finish_reason': None}]})}\n\n"
            except Exception as e:
                yield f"data: {json.dumps({'error': format_error(e)})}\n\n"
            finally:
                yield "data: [DONE]\n\n"
                # 更新 session 历史
                try:
                    if hasattr(handler, 'history_info'):
                        session['handler'].history_info = handler.history_info
                except Exception:
                    pass

        return StreamingResponse(event_stream(), media_type="text/event-stream")

    else:
        # ── Non-stream 模式 ──
        # 在后台线程中迭代 gen，避免阻塞 async 事件循环
        import asyncio
        loop = asyncio.get_event_loop()

        def consume_gen():
            full_resp = ""
            try:
                for chunk in gen:
                    full_resp += chunk
            except Exception as e:
                return f"Error: {format_error(e)}"
            # 更新 session 历史
            try:
                if hasattr(handler, 'history_info'):
                    session['handler'].history_info = handler.history_info
            except Exception:
                pass
            return full_resp

        full_resp = await loop.run_in_executor(None, consume_gen)

        return JSONResponse({
            "id": f"chatcmpl-{uuid.uuid4().hex[:8]}",
            "object": "chat.completion",
            "created": int(time.time()),
            "model": model,
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": format_chunk(full_resp)},
                "finish_reason": "stop"
            }]
        })


def setup_rtk_env(args):
    """Configure RTK environment variables based on CLI args.

    Auto-detects rtk binary: if installed and no --no-rtk, enables RTK_COMMANDS.
    Explicit --rtk / --no-rtk overrides auto-detection.
    """
    import shutil
    rtk_path = shutil.which("rtk")
    rtk_found = rtk_path is not None

    # --no-rtk: explicitly disable
    if getattr(args, 'no_rtk', False):
        if rtk_found:
            print("[ga_http_server] ⛔ RTK explicitly disabled (--no-rtk)")
        return

    # Auto-detect: if rtk installed, enable RTK_COMMANDS by default
    if args.rtk or (rtk_found and not getattr(args, 'no_rtk', False)):
        os.environ["RTK_COMMANDS"] = "1"
        auto = "(auto-detected)" if not args.rtk else ""
        print(f"[ga_http_server] ✅ RTK commands enabled: ls/tree/read/git etc → rtk proxy (compact output) {auto}")
    if rtk_found and args.rtk_filter:
        os.environ["RTK_FILTER"] = "1"
        print(f"[ga_http_server] ✅ RTK output filter enabled: code output piped through 'rtk pipe'")
    if rtk_found and args.rtk_ultra:
        os.environ["RTK_ULTRA"] = "1"
        print("[ga_http_server] ✅ RTK ultra-compact mode enabled (aggressive compression)")

    # Show rtk binary info if enabled
    if rtk_found and os.environ.get("RTK_COMMANDS"):
        print(f"[ga_http_server]   rtk binary: {rtk_path} (v{subprocess.run([rtk_path, '--version'], capture_output=True, text=True).stdout.strip().split()[1] if rtk_found else '?'})")
    elif not rtk_found and (args.rtk or args.rtk_filter):
        print("[ga_http_server] ⚠️  --rtk specified but rtk binary not found in PATH!")
        print("[ga_http_server]    Install: curl -fsSL https://rtk.dev/install.sh | sh")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="GA HTTP Server - OpenAI-compatible API for lucinate")
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--rtk', action='store_true', default=None,
                        help='Enable RTK proxy commands: ls/tree/read/git → rtk ls/rtk tree/rtk read/rtk git (compact output)')
    parser.add_argument('--no-rtk', action='store_true', default=False,
                        help='Disable RTK even if rtk binary is available')
    parser.add_argument('--rtk-filter', action='store_true', default=False,
                        help='Enable RTK output filter: pipe all code output through rtk pipe')
    parser.add_argument('--rtk-ultra', action='store_true', default=False,
                        help='Enable RTK ultra-compact mode (even more aggressive compression)')
    args = parser.parse_args()

    setup_rtk_env(args)

    print(f"[ga_http_server] Starting HTTP server at http://{args.host}:{args.port}")
    print(f"[ga_http_server] Configure lucinate: 'lucinate add-connection --name ga --url http://{args.host}:{args.port}/v1'")

    try:
        uvicorn.run(app, host=args.host, port=args.port)
    except KeyboardInterrupt:
        print("\n[ga_http_server] Shutting down...")


if __name__ == "__main__":
    main()
