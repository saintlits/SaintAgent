# Vision API SOP

## ⚠️ 前置规则（必须遵守）

1. **先枚举窗口**：调用 vision 前必须先用 `pygetwindow` 枚举窗口标题，确认目标窗口存在且已激活到前台。窗口不存在就不要截图。

## 快速用法

```python
from memory.vision_api import ask_vision

# 用法1：本地文件
ask_vision('/path/to/image.png', prompt='描述图片内容')

# 用法2：PIL Image
from PIL import Image
img = Image.open('/path/to/image.png')
ask_vision(img, prompt='描述图片内容')

# 用法3：URL 链接（自动下载）
ask_vision('https://example.com/image.png', prompt='描述图片内容')

# 用法4：纯文本（不传图片）
ask_vision('你好，请自我介绍')

# 用法5：指定后端
ask_vision('/path/to/image.png', prompt='描述图片内容', backend='openai')

# 返回 str：成功为模型回复，失败为 'Error: ...'
```

## 可用后端

| 后端 | 说明 |
|---|---|
| `mlx_qwen` | MLX 本地推理，Qwen3.6-35B-A3B 6bit VLM |
| `claude` | Claude（Anthropic）|
| `openai` | OpenAI |
| `modelscope` | ModelScope（国产兜底）|

默认后端为 `mlx_qwen`（6bit VLM，有视觉能力）。

⚠️ **注意**：mykey 中 `native_oai_config1` 是 6bit VLM（有视觉），`MLX_QWEN_CONFIG_KEY` 已设为 `'native_oai_config1'`。

## 如果没有 `vision_api.py`，初次构建 vision 能力

1. 复制 `memory/vision_api.template.py` → `memory/vision_api.py`
2. 只改头部"用户配置区"：去 `mykey.py` 里扫描变量名（⚠️ 只看名字，禁止输出 apikey 值），填入 `MLX_QWEN_CONFIG_KEY`（推荐）/ `CLAUDE_CONFIG_KEY` / `OPENAI_CONFIG_KEY`，`DEFAULT_BACKEND` 选后端，并测试
3. 保底：没有可用 config 时去 `https://modelscope.cn/my/myaccesstoken` 申请 token 填入 `MODELSCOPE_API_KEY`

## Browser Agent — 浏览器复杂操作标准流程

### 核心原则

**DOM 提供结构化数据，JS 做精确定位，Vision 补充看不到的内容。**

- `web_scan`: 快速扫描 HTML 结构，找 pattern / class
- `web_execute_js`: 批量提取 + 截图 + 交互操作
- `BrowserAgent`: 封装标准工作流（`memory.browser_agent`）

### 标准流程（3 轮以内完成复杂任务）

```
web_scan() → 识别目标元素的 class/id
web_execute_js("提取数据 + 截图") → 批量获取结构化数据
VLM 分析截图 → 补充缺失信息
JS 精确定位 → 根据 VLM 反馈操作
截图验证 → 确认操作结果
```

### 使用示例

```python
from memory.browser_agent import BrowserAgent, create_browser_agent

# 创建实例
agent = create_browser_agent()

# 复杂提取
data = agent.extract_structured("从当前页面提取所有商品名称和价格")

# 填表/登录
agent.fill_form({
    'selector': '#username', 'value': 'user123',
    'submit_selector': '#login-btn'
})
agent.confirm_state("已登录，显示用户名 xxx")

# 多步流程
result = agent.multi_step_flow([
    {'action': 'click', 'selector': '#settings'},
    {'action': 'fill', 'selector': '#name', 'value': 'test'},
    {'action': 'confirm', 'expected': '保存成功'}
])
```

### 什么时候用 Vision

- 动态页面（SPA）—— DOM 加载后实际渲染与预期不符
- iframe 内容
- 验证码/图形识别
- 验证码确认操作结果
- 复杂表格/图表（比 DOM 提取高效）

### 参数

- `max_pixels=4000000` — 截图分辨率上限（≈2000×2000）
- `max_tokens=2048` — VLM 输出 token 上限（允许结构化输出）

## Auto Pipeline — 桌面元素定位渐进逼近流程

### 核心原则

**VLM 只做坐标判断，其余全部由代码算法完成。整个循环除了 VLM 的坐标输出外不产生任何新的推理调用。**

### 流程

```
1. 全屏截图 → VLM 输出 {x, y}（绝对坐标）
2. moveTo(x, y) → 截图验证
3. 验证失败 → 裁剪目标区域 → 缩放至 512×512 → VLM 输出 {offset_x, offset_y}
4. 代码还原: x = cx + offset_x, y = cy + offset_y
5. moveTo(x, y) → 截图验证
6. 循环：缩小裁剪半径，重复步骤3-5
```

### 关键细节

- **全屏截图**：渐进逼近需要全局视野，全屏截图是必要的
- **固定尺寸裁剪**：所有裁剪统一缩放到 512×512，确保 VLM 始终看到一致尺寸
- **偏移还原**：VLM 只输出相对于裁剪中心的偏移量，代码负责还原为绝对坐标
- **渐进裁剪**：裁剪半径从 150px → 100px → 60px → ... 逐步缩小
- **输出格式**：prompt 只要求 JSON `{"x": N, "y": M}`，禁止任何推理文字

### 实现位置

- `memory/auto_pipeline/vlm_prompts.py` — LOCATE_PROMPT, RELATIVE_PROMPT
- `memory/auto_pipeline/pipeline.py` — _locate_absolute(), _locate_relative()
