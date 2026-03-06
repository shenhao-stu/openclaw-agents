<p align="center">
  <img src="https://img.shields.io/badge/OpenClaw-Multi--Agent-blue?style=for-the-badge" alt="OpenClaw">
  <br/>
  <img src="https://img.shields.io/badge/version-4.2.0-brightgreen?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/agents-8-orange?style=flat-square" alt="Agents">
  <img src="https://img.shields.io/badge/discord-native%20multi--bot-purple?style=flat-square" alt="Discord">
</p>

<h1 align="center">OpenClaw Agents</h1>

<p align="center">
  <strong>多智能体舰队配置 + Discord 子线程协作 SOP</strong>
  <br/>
  <em>一个 setup.sh → 8 个 Agent，每个 Agent 独立 Discord Bot、workspace、identity。</em>
</p>

<p align="center">
  <a href="#快速开始">快速开始</a> •
  <a href="#架构">架构</a> •
  <a href="#discord-线程模型">Discord 模型</a> •
  <a href="#sop">SOP</a> •
  <a href="./README.md">English</a>
</p>

---

## 这是什么

`openclaw-agents` 配置一个 8 Agent 的 OpenClaw 舰队，支持 Discord 多 Bot 路由：

- `setup.sh` 创建 Agent、workspace、icons、路由规则、Discord mention 规则。
- 每个 Agent 对应一个独立的 Discord Bot 账号。OpenClaw 通过 `accountId` → `agentId` binding 原生路由。
- `SKILL.md` 是 AI Agent 入口（遵循 [AgentSkills](https://skills.sh/) 规范）。

---

## 快速开始

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh scripts/discord-thread-dispatch.sh
./setup.sh
```

本地模式：

```bash
openclaw gateway
openclaw tui
```

Discord 模式（配置好 Bot Token 后）：

```bash
openclaw gateway
openclaw message thread create --channel discord \
  --target channel:<频道ID> \
  --thread-name "planner: 任务" \
  --message "协调 coder 和 reviewer。" --account planner
```

AI Agent 先读 `SKILL.md`。

---

## 架构

### 第一层 — 舰队配置

`./setup.sh`：

1. 检查 `openclaw` + `jq`
2. 创建 8 个 Agent，独立 workspace 位于 `~/.openclaw/workspace-<id>`
3. 部署 bootstrap、source 文件、openclaw-icons
4. 生成 `~/.openclaw/openclaw.json`（Agent 列表、bindings、Discord 配置）
5. Discord 模式：注入 mentionPatterns 和 mention guard

### 第二层 — Discord 多 Bot 路由

每个 Agent = 一个 Discord Bot 账号。OpenClaw 配置：

```json5
{
  bindings: [
    { agentId: "planner", match: { channel: "discord", accountId: "planner" } },
    { agentId: "coder",   match: { channel: "discord", accountId: "coder" } },
  ],
  channels: { discord: { accounts: { planner: { token: "..." }, coder: { token: "..." } } } }
}
```

参考：[Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent)，[Discord](https://docs.openclaw.ai/channels/discord)

---

## Discord 线程模型

| 概念 | 含义 |
|------|------|
| 父线程 | 面向用户。Planner 协调。最终总结发这里。 |
| 子线程 | Agent 协作。Coder、Reviewer 等在这里工作。 |
| Planner | 线程调度中心。 |

流程：`@planner` 接到任务 → 创建子线程 → 协调 coder/reviewer/surveyor → 回到父线程汇总 → @用户。

---

## 团队成员

| Agent | ID | 职责 |
|-------|-----|------|
| 🧠 Planner | `planner` | 任务拆解、协作调度、线程调度 |
| 💡 Ideator | `ideator` | 创意生成 |
| 🎯 Critic | `critic` | 品鉴、品味关卡 |
| 📚 Surveyor | `surveyor` | 文献搜索、research gap |
| 💻 Coder | `coder` | 实现、实验 |
| ✍️ Writer | `writer` | 写作、表述 |
| 🔍 Reviewer | `reviewer` | 评审、质检 |
| 📰 Scout | `scout` | 趋势监控、论文情报 |

---

## SOP

配置：

```bash
./setup.sh --mode channel --channel discord --group-id <guild-id>
```

设置 Bot Token：

```bash
openclaw config set channels.discord.accounts.planner.token '"TOKEN"' --json
openclaw config set channels.discord.accounts.coder.token '"TOKEN"' --json
# ... 每个 agent 分别设置
```

启动：

```bash
openclaw gateway
```

创建子线程：

```bash
./scripts/discord-thread-dispatch.sh --channel <频道ID> \
  --agent planner --name "planner: auth bug" \
  --prompt "协调 coder 和 reviewer。完成后回父线程汇总。"
```

继续子线程：

```bash
./scripts/discord-thread-dispatch.sh --thread <线程ID> --prompt "从上次检查点继续。"
```

本地（无 Discord）：

```bash
openclaw tui
# 或: openclaw dashboard
# 或: openclaw agent --agent planner --message "你的任务"
```

---

## Discord Mention 规则

使用数字 ID：`<@123456789012345678>`。不要只放在表格或代码块里。末尾加一行纯文本保证通知。

---

## 仓库结构

```
openclaw-agents/
├── setup.sh                        # 舰队配置
├── SKILL.md                        # AI Agent 入口
├── agents.yaml                     # Agent 清单
├── openclaw-icons/                 # Agent 头像
├── docs/
│   ├── installation.md
│   ├── discord-setup.md            # Discord 多 Bot SOP
│   └── discord-thread-sop.md       # 线程协作 SOP
├── scripts/
│   └── discord-thread-dispatch.sh  # 线程调度器
├── examples/
│   └── openclaw.*.json
└── .agents/
    ├── planner/, coder/, ...
    └── workflows/
```

---

## 文档

- [SKILL.md](SKILL.md)
- [安装](docs/installation.md)
- [Discord 配置](docs/discord-setup.md)
- [线程 SOP](docs/discord-thread-sop.md)
- [OpenClaw 官方文档](https://docs.openclaw.ai/)

---

## License

[MIT](LICENSE)
