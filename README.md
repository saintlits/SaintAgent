# SaintAgent 🧠

圣的个人 AI 全栈工具集 — 深度定制的 Lucinate + GenericAgent + OpenWarp 三件套。

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
├── openwarp-config/       # OpenWarp 个人配置
│   ├── settings.toml      # 编辑器设置
│   └── keybindings.yaml   # 快捷键绑定
│
├── scripts/               # 集成胶水脚本
│   ├── build.sh           # 一键构建所有组件
│   └── dev.sh             # 开发环境启动
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

## 📜 组件来源

| 组件 | 上游仓库 | 本地原位置 |
|------|---------|-----------|
| Lucinate | `github.com/lucinate-ai/lucinate` | `/Users/Shared/code/lucinate/` |
| GenericAgent | 私有 | `/Users/Shared/code/app/GenericAgent/` |
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

各组件基于各自上游许可。此仓库为个人定制整合。
