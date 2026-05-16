# Build Notes

## macOS Code Signing: `linker-signed` 缺失导致 SIGKILL

### 问题描述

用 `make build-prod`（`go build -ldflags "-s -w" -trimpath`）构建后，二进制在 macOS 上启动即崩溃，被 `taskgated` 以 SIGKILL 杀死：

```
exception: SIGKILL (Code Signature Invalid)
termination: CODESIGNING — "Taskgated Invalid Signature"
```

### 根因

- Go 1.26 在默认 `go build` 时，链接器会自动生成 **`linker-signed`** 的 ad-hoc 签名（codesign flags `0x20002`），macOS 信任这种签名。
- 使用 `-s -w -trimpath` 等剥离调试信息的参数后，Go 链接器未能正确设置 `linker-signed` 标志，生成的 ad-hoc 签名只有普通 `adhoc`（flags `0x2`），被 macOS 26.5（及后续版本）的安全策略拒绝。

### 症状

| 指标 | 正常 🟢 | 异常 🔴 |
|------|--------|--------|
| CodeSign flags | `0x20002(adhoc,linker-signed)` | `0x2(adhoc)` |
| `spctl -a -vvv` | rejected（不影响运行） | rejected |
| 实际运行 | 正常启动 | 收到 SIGKILL，立即退出 |

### 诊断命令

```bash
# 检查 codesign flags
codesign -dvvv ./lucinate | grep -E "flags|Signature"

# spctl 评估（仅参考，非决定性）
spctl -a -vvv ./lucinate

# 快速测试运行
./lucinate --version
```

### 修复方法

**使用 `make build` 而非 `make build-prod` 构建**：

```bash
# ✅ 正确：生成 linker-signed 签名
make build

# ❌ 问题：-s -w -trimpath 会破坏 linker-signed
make build-prod
```

`make build` 实际执行：
```bash
go build -ldflags "-X github.com/lucinate-ai/lucinate/internal/version.Version=<version>" -o lucinate .
```

如果必须精简二进制体积，可考虑构建后用 `strip` 精简（不破坏签名），**不要用 `-s -w` 编译参数**。

### 相关环境

- macOS: 26.5 (25F71)
- Go: 1.26.0 darwin/arm64
- 受影响构建参数: `-ldflags "-s -w"`, `-trimpath`
