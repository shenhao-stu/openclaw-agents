<p align="center">
  <img src="https://img.shields.io/badge/OpenClaw-Multi--Agent-blue?style=for-the-badge" alt="OpenClaw">
  <br/>
  <img src="https://img.shields.io/badge/version-3.1.0-brightgreen?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/agents-9-orange?style=flat-square" alt="Agents">
  <img src="https://img.shields.io/badge/discord-thread%20orchestration-purple?style=flat-square" alt="Discord Threads">
</p>

<h1 align="center">🐾 OpenClaw Agents（多智能体集群）</h1>

<p align="center">
  <strong>OpenClaw agent fleet + Discord 子线程协作 SOP</strong>
  <br/>
  <em>先用 OpenClaw 配好多智能体，再在 Discord 中跑 planner 主导的父线程 / 子线程协作。</em>
</p>

<p align="center">
  <a href="#-快速开始">快速开始</a> •
  <a href="#-工作原理">工作原理</a> •
  <a href="#-discord-协作模型">Discord 协作模型</a> •
  <a href="#-团队成员">团队成员</a> •
  <a href="#-planner-子线程-sop">Planner 子线程 SOP</a> •
  <a href="#-仓库结构">仓库结构</a> •
  <a href="./README.md">English Version</a>
</p>

---

## ✨ 这个仓库现在到底是什么

**OpenClaw Agents** 负责的是 **OpenClaw 智能体舰队本身**：

- 8 个核心子 Agent + 1 个主 Agent 身份
- 每个 Agent 的独立 workspace
- 自我合并用的 `BOOTSTRAP.md`
- OpenClaw 的本地 / 渠道路由配置
- Planner 为中心的协作规范

而 **外部 Discord 运行时** 负责的是 **Discord 这一层的线程 / session 能力**：

- Discord Bot
- 项目频道
- 任务线程
- 线程与 session 的映射
- `send --channel / --thread / --session` 这类继续对话能力

所以这个分支的核心原则是：

- **OpenClaw Agents = agent fleet**
- **外部 Discord 运行时 = Discord thread/session runtime**

这次文档重构的目标就是把这个边界写清楚，不再混淆。

---

## 🚀 快速开始

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh scripts/discord-thread-dispatch.sh
./setup.sh
```

如果你还想在 Discord 里跑 planner 子线程，就配置好你自己的 Discord 运行时，然后通过这个仓库自带的派发脚本创建或继续线程：

```bash
./scripts/discord-thread-dispatch.sh --channel <project-channel-id> --prompt "为这个任务创建一个 planner 子线程" --dry-run
```

建议按顺序阅读：

- `docs/installation.md`
- `docs/discord-setup.md`
- `docs/discord-thread-sop.md`

---

## 🧠 工作原理

### 第一层：OpenClaw 舰队配置

`./setup.sh` 会：

1. 检查 `openclaw` 和 `jq`
2. 创建 8 个核心子 Agent
3. 在 `~/.openclaw/workspace-<id>` 下创建工作区
4. 下发 `_soul_source.md` / `_user_source.md` / `_agent_source.md` / `BOOTSTRAP.md`
5. 把 workflow 参考追加到每个 Agent 的 `AGENTS.md`
6. 更新 `~/.openclaw/openclaw.json`
7. 如果选择 Discord，则补充真实 `<@...>` mention 规则并注入 mention guard

### 第二层：Discord 线程 / Session 运行时

外部 Discord 运行时提供：

- 一个项目对应一个 Discord channel
- 一个任务对应一个 Discord thread
- `send --channel` 创建新任务线程
- `send --thread` 或 `--session` 继续已有线程
- `--worktree` 提供隔离执行环境
- `--notify-only` 提供只建线程不立即执行的壳

也就是说，这个仓库现在明确采用：

- OpenClaw 负责 agent fleet
- 外部 Discord 运行时负责 Discord 线程协作

---

## 💬 Discord 协作模型

建议你始终用下面这个心智模型：

- **Discord channel = 项目**
- **Discord thread = 任务 / session**
- **父线程 = planner 面向用户的总控线程**
- **子线程 = 某个具体子任务的执行线程**

### 为什么这样设计

这个仓库本身没有 Discord bot runtime，也没有原生的“创建子区”实现。

所以最真实、最稳妥的做法不是硬吹一个并不存在的功能，而是：

1. 用 OpenClaw 把 agent fleet 配好
2. 用你自己的 Discord 运行时把 channel/thread/session 跑起来
3. 让 planner 管理父线程
4. 让 coder / reviewer / surveyor 等在子线程中完成细节工作
5. 最后由 planner 回到父线程给用户总结

---

## 🤖 团队成员

| Agent | ID | 核心职责 |
|---|---|---|
| 🐾 OpenClaw | `main` | 主控、审计、最终仲裁 |
| 🧠 Planner | `planner` | 任务拆解、协作调度、进度汇总 |
| 💡 Ideator | `ideator` | 生成想法、塑造贡献点 |
| 🎯 Critic | `critic` | SHARP 品鉴、反模式审查 |
| 📚 Surveyor | `surveyor` | 文献搜索、research gap 定位 |
| 💻 Coder | `coder` | 实现、实验、修复 |
| ✍️ Writer | `writer` | 写作、表述、整理 |
| 🔍 Reviewer | `reviewer` | 评审、质检、否决 |
| 📰 Scout | `scout` | 趋势监控、论文情报 |

### Planner 为什么最关键

在这个仓库里，Planner 本来就是：

- 统筹者
- 调度中心
- 进度板维护者
- 用户汇报出口

因此，Planner 也是最自然的 **父线程 owner**。

---

## 🧵 Planner 子线程 SOP

### 1）立刻创建一个子线程

```bash
./scripts/discord-thread-dispatch.sh \
  --channel <project-channel-id> \
  --agent planner \
  --name "planner: auth bug triage" \
  --prompt "开一个子线程，在里面协调 coder 和 reviewer，完成后回父线程总结最终结果。"
```

### 2）先建一个 notify-only 的线程壳

```bash
./scripts/discord-thread-dispatch.sh \
  --channel <project-channel-id> \
  --notify-only \
  --name "planner: release review" \
  --prompt "Planner 子线程已创建。请在这里继续执行，最终结果回父线程汇总。"
```

### 3）继续已有子线程

```bash
./scripts/discord-thread-dispatch.sh \
  --thread <thread-id> \
  --agent coder \
  --prompt "继续上一个检查点，并给出 patch summary。"
```

### 4）按 session ID 继续

```bash
./scripts/discord-thread-dispatch.sh \
  --session <session-id> \
  --agent reviewer \
  --prompt "审查最新改动，并区分 blocker 和 non-blocker。"
```

### 5）用 worktree 做隔离执行

```bash
./scripts/discord-thread-dispatch.sh \
  --channel <project-channel-id> \
  --agent coder \
  --worktree issue-123 \
  --name "issue-123 fix" \
  --prompt "在独立 worktree 中修复这个问题，并汇报测试状态。"
```

完整版本见：`docs/discord-thread-sop.md`

---

## ⚠️ Discord mention 最大坑点

Discord 的真实 mention 形式是：

```text
<@123456789012345678>
```

不要只把它们塞进表格或代码块。

### 错误示例

```markdown
| Agent | Task |
|---|---|
| <@123456789012345678> | 修复登录问题 |
```

### 正确示例

```text
<@123456789012345678>，请立刻开始上面的任务。
```

这就是为什么 `setup.sh` 在 Discord 模式下会自动往每个 Agent 的提示词里注入 mention guard。

---

## 🔧 配置模式

### 本地模式

```bash
./setup.sh --mode local
```

适合只想用 OpenClaw 原生 `agentToAgent` 协作的人。

### 渠道模式

```bash
./setup.sh --mode channel --channel feishu --group-id oc_xxx
./setup.sh --mode channel --channel telegram --group-id -1001234567890
./setup.sh --mode channel --channel discord --group-id 123456789012345678
```

常用组合：

```bash
./setup.sh \
  --mode channel \
  --channel discord \
  --group-id 123456789012345678 \
  --model zai/glm-5 \
  --model-map 'coder=ollama/kimi-k2.5:cloud,writer=zai/glm-4.7' \
  --require-mention true
```

---

## ✅ 验证方式

### OpenClaw 侧

```bash
openclaw agents list --bindings
openclaw gateway
```

### Discord 运行时侧

确认你的外部 Discord 运行时已经在线，并且能正确连接项目频道 / 线程。

然后确认：

- Bot 在线
- 项目频道已建立
- 发消息会创建或继续线程
- `./scripts/discord-thread-dispatch.sh --dry-run ...` 能生成正确命令

---

## 📁 仓库结构

```text
openclaw-agents/
├── setup.sh                     # OpenClaw fleet 配置脚本
├── agents.yaml                  # manifest / 元数据参考
├── docs/
│   ├── installation.md          # 安装指南
│   ├── discord-setup.md         # Discord 配置指南
│   └── discord-thread-sop.md    # 父线程/子线程 SOP
├── scripts/
│   └── discord-thread-dispatch.sh # 通用 Discord 线程派发包装
├── examples/
│   ├── openclaw.local.json
│   ├── openclaw.feishu.json
│   ├── openclaw.telegram.json
│   └── openclaw.whatsapp.json
└── .agents/
    ├── planner/
    ├── ideator/
    ├── critic/
    ├── surveyor/
    ├── coder/
    ├── writer/
    ├── reviewer/
    ├── scout/
    └── workflows/
```

---

## 📚 相关文档

- [Installation](docs/installation.md)
- [Discord Setup Guide](docs/discord-setup.md)
- [Discord Thread SOP](docs/discord-thread-sop.md)
- [English README](README.md)

---

## 📄 License

[MIT](LICENSE)
