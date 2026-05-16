# SaintAgent 🧠

AI 全栈工具集 — 深度定制的 Lucinate + GenericAgent + OpenWarp 三件套。

## 📦 项目结构

```
SaintAgent/
├── lucinate/              # AI CLI / TUI 聊天前端 (Go)
│   ├── cmd/               # 入口命令
│   ├── internal/tui/      # TUI 终端界面 (bubbletea)
│   └── internal/backend/  # 后端 API 交互
│
├── genericagent/          # 通用 AI Agent 框架 (Python)
│   ├── ga.py              # 主入口
│   ├── agent_loop.py      # Agent 循环
│   ├── frontends/         # 支持多种前端
│   └── memory/            # 长期记忆系统
│
├── openwarp/              # OpenWarp 编辑器 (Rust)
│   ├── crates/            # 模块化 crate
│   └── Cargo.toml
│
├── scripts/               # 集成胶水脚本
│   ├── build.sh           # 一键构建所有组件
│   ├── dev.sh             # 开发环境信息
│   ├── run-agent.sh       # 🎯 一键启动 Agent 工作流 (GA + Lucinate ± OpenWarp)
│   ├── run.sh             # 通用启动器 (集成三件套)
│   ├── chat.sh            # Lucinate TUI 直接启动
│   ├── serve.sh           # GA HTTP 后端服务管理
│   ├── openwarp.sh        # OpenWarp 编辑器启动器
│   ├── status.sh          # 组件健康检查 & 系统信息
│   ├── logs.sh            # 统一日志查看器
│   ├── test.sh            # 跨组件测试运行器
│   └── update.sh          # 依赖更新 & 项目同步
│
├── README.md
└── .gitignore
```

## 🧠 架构概览

> SaintAgent 的核心理念是 **"三件套 + 胶水"**：一个 AI 推理引擎（GenericAgent）× 一个智能对话 TUI（Lucinate）× 一个代码编辑器（OpenWarp），通过一体化脚本（Scripts）无缝协作。
>
> 三者各自独立、可选替换，但组合起来提供完整的 Agent 工作流体验。
>
> **关键设计决策：** 一切通过 HTTP（OpenAI 兼容 API）通信，任何兼容的 TUI 或 LLM 后端都可即插即用。

### 架构总览

```
┌──────────────────────────────────────────────────────────────┐
│                     SaintAgent 运行时                         │
│                                                              │
│  ┌──────────────┐      HTTP/SSE (stream)      ┌────────────┐ │
│  │              │ ◄──────────────────────────► │            │ │
│  │  Lucinate    │  POST /v1/chat/completions   │GenericAgent│ │
│  │  (Go TUI)    │  GET /v1/models              │ (Python)   │ │
│  │              │  GET /health                 │ HTTP Server│ │
│  │  用户交互界面│                               │  AI 推理引擎│ │
│  │              │       OpenAI API 兼容         │            │ │
│  └──────┬───────┘                              └─────┬──────┘ │
│         │                                            │        │
│         │ 终端渲染 (bubbletea)                        │        │
│         │ emoji/中文支持 (runewidth)                  ├─ LLM   │
│         │                                            ├─ RTK ℹ️│
│         │                                            │  输出  │
│         │                                            │  压缩  │
│         │                                            ├─ Tools │
│  ┌──────┴───────┐                                   ├─ Memory│
│  │              │                                   │  注:  │
│  │              │                                   └────┬────┘
│  │  OpenWarp    │ (optional)                             │
│  │  (Rust)      │                              ┌─────────┴────┐
│  │  代码编辑器   │                              │  Scripts     │
│  │              │                              │  (胶水层)     │
│  └──────────────┘                              │  run-agent.sh │
│                                                │  serve.sh     │
│          ┌──────────────────┐                  │  chat.sh      │
│          │  openwarp-config │                  │  status.sh    │
│          │  (用户配置)      │                  └──────────────┘
│          └──────────────────┘
└──────────────────────────────────────────────────────────────┘
```

### 核心数据流

1. **用户输入** → Lucinate TUI 捕获键盘输入，渲染气泡界面
2. **API 转发** → Lucinate 通过 `LUCINATE_OPENAI_BASE_URL` 环境变量指向 `http://127.0.0.1:8080/v1`，发送 OpenAI 格式请求
3. **GA 处理** → GenericAgent HTTP Server 接收请求，启动 Agent Loop：
   - LLM 推理（通过 llmcore 调用模型）
   - 工具调用（浏览器/OCR/代码执行等）→ 输出经 **RTK 压缩** 后进入 LLM 上下文
   - 记忆读写（SOP 体系 + 长期记忆）
4. **RTK 压缩** → 工具调用输出（ls / tree / git / read 等命令）被 RTK 代理命令拦截压缩，大幅降低 token 消耗（典型 50–76%）
5. **流式返回** → GA 以 SSE (Server-Sent Events) 格式流式返回 token，支持实时打字机效果
6. **渲染输出** → Lucinate 实时渲染响应（Markdown、代码块、工具调用日志）

```
【用户】  ──键盘──▶  Lucinate  ──HTTP──▶  GA Server  ──▶  Agent Loop
                                                                 │
                          ┌──────────────────────────────────────┘
                          ▼                                     
                    ┌──────────┐                                 
                    │  LLM     │  ◀── RTK 压缩后的工具输出      
                    │  推理     │                                 
                    └────┬─────┘                                 
                         │ 需更多信息                            
                         ▼                                     
                    ┌──────────┐    ┌──────────────────┐        
                    │  Tool    │───▶│  RTK (Middleware) │──▶ 回 LLM
                    │  Execute │    │  ls→rtk ls       │    上下文
                    │  (code)  │    │  git→rtk git     │        
                    └──────────┘    │  tree→rtk tree   │        
                                    │  ...              │        
                                    └──────────────────┘        

◀──SSE stream──  Lucinate  ◀──chunks──────  最终响应
```

### 启动编排

`scripts/run-agent.sh` 管理完整的启停生命周期：

| 步骤 | 动作 | 说明 |
|------|------|------|
| 1 | 前置检查 | 验证 `mykey.py`（API 密钥）、编译产物 |
| 2 | 启动 GA Server | `python ga_http_server.py --host 127.0.0.1 --port 8080`（后台 daemon） |
| 3 | 等待就绪 | 轮询 `/health` 端点，超时 15 次 × 0.5s |
| 4 | (可选) 启动 OpenWarp | 作为独立进程启动，指定工作目录 |
| 5 | 启动 Lucinate TUI | 设置环境变量后 `exec lucinate`（前台，替换 shell 进程） |
| 停止 | 停止 GA Server | 读取 PID 文件 → `kill` → 清理 |

各组件也可单独启动：`./scripts/serve.sh`（GA 后端）、`./scripts/chat.sh`（Lucinate TUI）、`./scripts/openwarp.sh`（编辑器）。

### 组件协作矩阵

| 场景 | Lucinate | GenericAgent | OpenWarp | Scripts |
|------|----------|-------------|----------|---------|
| 日常 Agent 对话 | ✅ 前端 | ✅ 推理引擎 | ❌ | ✅ 启动 |
| 编码 + Agent 辅助 | ✅ 前端 | ✅ 推理+工具 | ✅ 编辑 | ✅ 启动 |
| 仅 GA 后端服务 | ❌ | ✅ HTTP API | ❌ | ✅ serve.sh |
| 调试/开发 | ❌ | ✅ 直连(ga.py) | ❌ | ✅ dev.sh |

### 定制集成点

架构设计保证每个组件都可独立定制而不影响其他部分：

- **换 TUI 前端** — 任何兼容 OpenAI API 的客户端（如 NextChat、ChatGPT-Next-Web）只需修改 `base_url` 即可替换 Lucinate
- **换 LLM 后端** — GenericAgent 的 `llmcore.py` 支持多 provider，可通过 `mykey.py` 配置
- **添加工具** — GA 的工具系统是模块化的，新增 tool 只需注册 schema 和 handler
- **换编辑器** — OpenWarp 可用 VSCode/Nvim 等替代，编辑器不依赖其他组件

### RTK 输出压缩层

> [RTK (Real-Time Kit)](https://github.com/rtk-ai/rtk) 是一个 CLI 输出压缩工具，在 GenericAgent 中充当 **Agent 工具执行的中间件**，大幅降低 AI 工具调用的 token 消耗。

在 GenericAgent 的标准数据流中，Agent 执行 bash 命令后，原始输出被完整送入 LLM 上下文窗口。RTK 通过 **命令代理** 机制拦截并压缩管道：

```
Agent 执行命令                            LLM 收到的输出
┌──────────┐    ┌──────────────┐    ┌──────────────────────┐
│  code_run │───▶│  RTK Proxy   │───▶│  compact, structured│
│  ls -la   │    │  rtk ls -la  │    │  ~530 chars (原 2200)│
└──────────┘    └──────────────┘    └──────────────────────┘
```

**工作原理：**

- **命令映射表** — `ga.py` 内置 `RTK_COMMAND_MAP`，将常见命令替换为 RTK 代理版本：
  `ls→rtk ls`, `tree→rtk tree`, `read→rtk read`, `git→rtk git`, `docker→rtk docker`, `ps→rtk ps`, `grep→rtk grep`, `diff→rtk diff`
- **智能跳过** — 含管道、重定向、复杂语法的命令不做替换，避免破坏语义
- **失败回退** — RTK 执行失败时自动回退到原始系统命令

**效果评估：**

| 命令 | 原始输出 | RTK 压缩后 | 节省 |
|------|---------|-----------|------|
| `ls -la` | ~2200 chars | ~530 chars | **76%** |
| `git status` | ~800 chars | ~200 chars | **75%** |
| `tree` | ~1500 chars | ~400 chars | **73%** |

**启动方式：**

```bash
# 自动检测（已安装 rtk 时默认启用）
python ga_http_server.py

# 显式控制
python ga_http_server.py --rtk           # 强制启用
python ga_http_server.py --rtk-filter    # 同时启用输出过滤
python ga_http_server.py --rtk-ultra     # 超紧凑模式
python ga_http_server.py --no-rtk        # 禁用
```

RTK 是可选优化层，不影响功能正确性，仅在安装 `rtk` 后生效。它使 Agent 在相同上下文窗口内能处理更多信息密度。

### 与上游的关系

| 组件 | 基础来源 | SaintAgent 定制 |
|------|---------|----------------|
| Lucinate | [lucinate-ai/lucinate](https://github.com/lucinate-ai/lucinate) | TUI 中文化(emoji换行/透明背景)、预配置 GA 后端连接 |
| GenericAgent | [lsdefine/GenericAgent](https://github.com/lsdefine/GenericAgent) | SOP 记忆体系、浏览器集成、OCR/Vision 工具链 |
| OpenWarp | [warpdotdev/OpenWarp](https://github.com/warpdotdev/OpenWarp) | 个人 settings.toml + keybindings.yaml |
| Scripts | 自研 | 100% 自制，起胶水+编排作用 |

每个子项目都保持独立的 git history（可从上游更新），`scripts/update.sh` 负责同步上游变更。

## 🚀 快速开始

### 前置依赖

- Go 1.22+
- Python 3.12+
- Rust (nightly)
- uv (Python 包管理器)

### 构建

```bash
chmod +x scripts/build.sh
./scripts/build.sh
```

### 开发

```bash
./scripts/dev.sh
```

## 🔧 脚本速查

```bash
./scripts/run-agent.sh                  # 🎯 一键启动：GA 服务 + Lucinate TUI
./scripts/run-agent.sh --openwarp       # 启动三件套（+ OpenWarp 编辑器）
./scripts/run-agent.sh --status         # 查看服务状态
./scripts/run-agent.sh --stop           # 停止所有服务

./scripts/build.sh                      # 构建所有组件
./scripts/dev.sh                        # 开发环境信息
./scripts/status.sh                     # 详细组件健康检查
./scripts/logs.sh                       # 查看 GA 服务日志
./scripts/logs.sh --follow              # 持续跟踪日志
./scripts/test.sh                       # 运行所有测试
./scripts/update.sh                     # 更新所有组件依赖
```

## 📜 组件来源

| 组件 | 上游仓库 | 本地原位置 |
|------|---------|-----------|
| Lucinate | `github.com/lucinate-ai/lucinate` | `/Users/Shared/code/lucinate/` |
| GenericAgent | `github.com/lsdefine/GenericAgent` | `/Users/Shared/code/app/GenericAgent/` |
| OpenWarp | `github.com/warpdotdev/OpenWarp` | `/Users/Shared/code/app/openwarp/` |

## 🛠️ 自定义改动说明

### Lucinate 定制
- TUI 修复：textarea 背景透明化、中文/emoji 换行修复 (runewidth)、轮次分隔线
- 编译: `cd lucinate && go build -o lucinate ./cmd/lucinate/`

### GenericAgent 定制
- 丰富的 SOP 记忆体系
- 浏览器控制集成
- OCR / Vision 工具链

### OpenWarp 定制
- 自定义 settings.toml
- 自定义 keybindings.yaml

## 📝 许可

各组件基于各自上游许可。此仓库为个人定制整合。可自由进行二次分发
