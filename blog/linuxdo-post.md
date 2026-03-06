# 在 Discord 上搭建 8 Agent 协作系统（OpenClaw 原生多 Bot 方案）

> 本文基于实际部署经历整理，从零讲清如何用 OpenClaw 配置一套 8 人 AI Agent 协作舰队，通过 Discord 多 Bot 账号实现 parent-thread / child-thread 协作流，**全程使用 OpenClaw 原生能力，不依赖第三方 bridge**。附 ACP 对接 OpenCode 方案和反思/快照指令设计。

---

## 📑 目录

1. [整体架构](#整体架构)
2. [前置准备](#前置准备)
3. [第一步：安装 OpenClaw](#第一步安装-openclaw)
4. [第二步：克隆仓库并执行 setup.sh](#第二步克隆仓库并执行-setupsh)
5. [第三步：创建 Discord Bot 并配置 Token](#第三步创建-discord-bot-并配置-token)
6. [第四步：启动 Gateway 验证](#第四步启动-gateway-验证)
7. [第五步：线程协作实操](#第五步线程协作实操)
8. [第六步：ACP 对接 OpenCode（Coder Agent 增强）](#第六步acp-对接-opencodecoder-agent-增强)
9. [第七步：反思与快照指令](#第七步反思与快照指令)
10. [踩坑合集](#踩坑合集)

---

## 整体架构

整个方案由三层组成：

- **setup.sh** 一键配置 8 个 Agent 的 workspace、identity、routing 规则
- **OpenClaw Gateway** 原生 Discord 多 Bot 路由，每个 Agent 一个 Discord Bot 账号
- **ACP (可选)** 通过 acpx 插件对接 OpenCode / Claude Code / Codex 等外部编码引擎

> 💡 **为什么不用 kimaki？** kimaki 是 OpenCode 专用的 Discord bridge，适合单 Bot 场景。我们需要 8 个独立 Bot 分别绑定到 8 个 Agent，OpenClaw 原生的 `accountId` 路由正好能做这件事。kimaki 的线程模型（channel = project, thread = session）是本方案的设计灵感来源。

![architecture-placeholder]
> 架构示意图

---

## 前置准备

| 项目 | 要求 |
|------|------|
| Node.js | >= 22 |
| jq | setup.sh 依赖 |
| Discord | 一个私有 Server，Developer Mode 开启 |
| Discord Bot | 每个 Agent 创建一个 Application/Bot（共 8~10 个） |

---

## 第一步：安装 OpenClaw

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
openclaw onboard --install-daemon
```

验证：

```bash
openclaw --version
openclaw gateway status
```

> 💡 **不再推荐** `npm install -g openclaw@latest`，官方推荐 installer 脚本，自动处理 PATH 和 daemon 配置。

---

## 第二步：克隆仓库并执行 setup.sh

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
chmod +x setup.sh scripts/discord-thread-dispatch.sh
./setup.sh --mode channel --channel discord --group-id <你的Guild ID>
```

setup.sh 执行 8 步：

1. Preflight：检查 `openclaw` 和 `jq`
2. 创建 8 个 Agent（planner / ideator / critic / surveyor / coder / writer / reviewer / scout）
3. 设置 Agent identity（emoji + 名称）
4. 部署 bootstrap + source 文件到各 workspace
5. 部署 openclaw-icons
6. 追加 workflow 引用到 AGENTS.md
7. 生成 `~/.openclaw/openclaw.json` 路由配置
8. Discord 模式：注入 mentionPatterns + mention guard

![setup-sh-placeholder]
> setup.sh 执行截图

---

## 第三步：创建 Discord Bot 并配置 Token

去 [Discord Developer Portal](https://discord.com/developers/applications)，**每个 Agent 创建一个 Application**：

1. New Application → 命名（如 `OpenClaw-Planner`）
2. Bot 页面 → Reset Token → **保存 Token**
3. Bot 页面 → Privileged Gateway Intents → 开启 **Message Content Intent** + **Server Members Intent**
4. OAuth2 → URL Generator → 勾选 `bot` + `applications.commands`
5. Bot Permissions：View Channels / Send Messages / Send Messages in Threads / Read Message History / Embed Links / Attach Files / Add Reactions
6. 复制 Invite URL → 邀请 Bot 到你的 Server

> ⚠️ **每个 Agent 都需要一个独立的 Bot**。8 个 Agent = 8 个 Application = 8 个 Token。这不是浪费，这是 OpenClaw multi-account 路由的核心设计。

配置 Token：

```bash
openclaw config set channels.discord.enabled true --json
openclaw config set channels.discord.accounts.planner.token  '"MTQ...Token..."' --json
openclaw config set channels.discord.accounts.coder.token    '"MTQ...Token..."' --json
openclaw config set channels.discord.accounts.reviewer.token '"MTQ...Token..."' --json
# ... 每个 agent 分别设置
```

对应的 `openclaw.json` 结构：

```json5
{
  bindings: [
    { agentId: "planner", match: { channel: "discord", accountId: "planner" } },
    { agentId: "coder",   match: { channel: "discord", accountId: "coder" } },
    // ...
  ],
  channels: {
    discord: {
      groupPolicy: "open",
      accounts: {
        planner: {
          token: "BOT_TOKEN",
          streaming: "partial",
          guilds: { "<guildId>": { channels: { "<channelId>": { allow: true, requireMention: true } } } }
        },
        // ... 每个 agent 同结构
      }
    }
  }
}
```

![discord-config-placeholder]
> Discord Developer Portal 截图

---

## 第四步：启动 Gateway 验证

```bash
openclaw gateway
```

另开终端验证：

```bash
openclaw agents list --bindings
openclaw channels status --probe
```

预期：8 个 Agent 全部绑定到 Discord accountId，所有 Bot 在 Guild 中在线。

![gateway-status-placeholder]
> agents list --bindings 输出截图

---

## 第五步：线程协作实操

核心模型：

```
用户在 #project-channel @planner "调研 xxx 方向"
        ↓
Planner 创建子线程 "planner: xxx literature review"
        ↓
子线程内 @surveyor 搜文献、@coder 跑实验
        ↓
Planner 回父线程汇总 @用户
```

创建子线程：

```bash
openclaw message thread create --channel discord \
  --target channel:1478466947208446106 \
  --thread-name "planner: auth bug triage" \
  --message "协调 coder 和 reviewer，完成后回父线程汇总。" \
  --account planner
```

或用封装脚本：

```bash
./scripts/discord-thread-dispatch.sh \
  --channel 1478466947208446106 \
  --agent planner \
  --name "planner: auth bug" \
  --prompt "协调 coder 和 reviewer。完成后回父线程汇总。"
```

在子线程中发消息：

```bash
openclaw message send --channel discord \
  --target channel:<threadId> \
  --message "Coder: patch 已完成，@reviewer 请 review。" \
  --account coder
```

> 💡 **mention 的坑**：`<@数字ID>` 必须在纯文本中，不能只出现在 Markdown 表格/代码块里。setup.sh 已自动向每个 Agent prompt 注入 mention guard 警告。

![thread-flow-placeholder]
> Discord 子线程协作截图

---

## 第六步：ACP 对接 OpenCode（Coder Agent 增强）

OpenClaw 的 [ACP (Agent Client Protocol)](https://docs.openclaw.ai/tools/acp-agents) 原生支持接入 OpenCode、Claude Code、Codex、Gemini CLI 等外部编码引擎。

安装 acpx 插件：

```bash
openclaw plugins install acpx
openclaw config set plugins.entries.acpx.enabled true --json
openclaw config set plugins.entries.acpx.config.permissionMode approve-all --json
```

配置 coder agent 的 ACP runtime：

```json5
{
  agents: {
    list: [{
      id: "coder",
      runtime: {
        type: "acp",
        acp: { agent: "opencode", backend: "acpx", mode: "persistent" }
      }
    }]
  },
  acp: {
    enabled: true,
    backend: "acpx",
    allowedAgents: ["opencode", "claude", "codex"]
  }
}
```

使用：

```
/acp spawn opencode --mode persistent --thread auto
```

这样 coder agent 在 Discord 线程中接到编码任务时，实际由 OpenCode 引擎执行，具备完整的文件读写、终端操作、代码搜索能力。

> 💡 仓库 `examples/openclaw.acp-opencode.json` 提供了完整配置模板。acpx 支持的 harness 列表：`opencode`, `claude`, `codex`, `pi`, `gemini`, `kimi`。

---

## 第七步：反思与快照指令

仓库内置两个 Agent 指令模板（`.agents/commands/`），用于系统自进化：

### /reflect — 反思与经验固化

触发后 Agent 自动：
1. 扫描会话历史，提取用户偏好、任务模式、决策记录、遇到的问题
2. 识别重复出现的 SOP 流程
3. 将反思结果追加到 `MEMORY.md`
4. 将 SOP 转化为 `SKILL.md` 格式保存到 `~/.openclaw/skills/`

### /snapshot — 便携式状态导出

触发后生成一份自包含的上下文文档，包含：用户画像、任务状态、Agent 行为历史、已知问题、交接指令。

**即插即用**：将文档粘贴到任意 Agent 的 `USER.md` 或作为新会话首条消息发送，接收方 Agent 立即获得完整上下文。

> 💡 这两个指令的设计目标是让 Agent 系统具备 **长期记忆演化能力**。每次 `/reflect` 后系统积累经验，每次 `/snapshot` 后可无损迁移上下文。

---

## 踩坑合集

### 1. `openclaw chat` 不存在

官方 CLI 中没有 `chat` 子命令。正确的交互方式：

| 场景 | 命令 |
|------|------|
| 终端交互 | `openclaw tui` |
| 浏览器交互 | `openclaw dashboard` |
| 命令行单次 | `openclaw agent --agent planner --message "..."` |

### 2. JSON 拼接用 `jq -n`

setup.sh 中构建 JSON **不能用 shell heredoc 拼接**。转义符号会被 shell 吃掉，导致 `jq --argjson` 报 `invalid JSON`。用 `jq -n --arg` 逐字段构建后 `jq -s .` 聚合。

### 3. Discord mention 只认纯文本

`<@123456789>` 放在 Markdown 表格或代码块里 → Discord 当纯文本处理 → 对方收不到通知。必须在消息末尾追加一行纯文本 mention。

### 4. 安装方式改了

```bash
# 推荐
curl -fsSL https://openclaw.ai/install.sh | bash

# 也能用但不推荐
npm install -g openclaw@latest
```

### 5. multi-account 路由需要严格 accountId

每个 `bindings[].match.accountId` 必须和 `channels.discord.accounts.<name>` 的 key 完全一致。拼写错误会导致消息路由不到对应 Agent。

---

## 相关链接

| 资源 | 地址 |
|------|------|
| 仓库 | https://github.com/shenhao-stu/openclaw-agents |
| OpenClaw 文档 | https://docs.openclaw.ai/ |
| Discord 渠道 | https://docs.openclaw.ai/channels/discord |
| Multi-Agent 路由 | https://docs.openclaw.ai/concepts/multi-agent |
| ACP Agents | https://docs.openclaw.ai/tools/acp-agents |
| Sub-Agents | https://docs.openclaw.ai/tools/subagents |
| AgentSkills | https://skills.sh/ |
