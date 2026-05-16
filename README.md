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
