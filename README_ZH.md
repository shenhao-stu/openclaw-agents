<p align="center">
  <img src="https://img.shields.io/badge/OpenClaw-Multi--Agent-blue?style=for-the-badge" alt="OpenClaw">
  <br/>
  <img src="https://img.shields.io/badge/version-2.3.0-brightgreen?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/agents-9-orange?style=flat-square" alt="Agents">
  <img src="https://img.shields.io/badge/channels-feishu%20%7C%20whatsapp%20%7C%20telegram%20%7C%20discord-purple?style=flat-square" alt="Channels">
</p>

<h1 align="center">🐾 OpenClaw Agents (多智能体集群)</h1>

<p align="center">
  <strong>专为 <a href="https://docs.openclaw.ai">OpenClaw</a> 打造的一键式多智能体部署脚手架</strong>
  <br/>
  <em>只需一条命令，即可在 60 秒内将整个 AI 研究团队部署到你的聊天群组中。默认模型：<code>zai/glm-5</code></em>
</p>

<p align="center">
<a href="#-安装与部署">安装与部署</a> •
<a href="#-架构设计">架构设计</a> •
<a href="#-团队成员">团队成员</a> •
<a href="#-渠道支持">渠道支持</a> •
<a href="#-自定义工作流">自定义工作流</a> •
<a href="./README.md">🇺🇸 English Version</a>
</p>

---

## ✨ 核心特性

**OpenClaw Agents** 是一个开箱即用的多智能体预配置包。它只需一条命令，就能配置 **9 个专业化 AI 角色** 作为一个协同研究团队——并自动处理身份、工作区、路由规则以及渠道绑定。

### 包含的内容

- 🤖 **9 个预配置 Agent**，配备直观的 emoji 身份标识（在聊天中极具辨识度）
- 📝 **自动自我融合**（Self-merge）：通过下发 `BOOTSTRAP.md` 实现无损首次启动
- 🔗 **双部署模式**: 
  - **渠道模式 (Channel Mode)**: 自动路由到 Feishu、WhatsApp、Telegram 或 Discord（支持每人单群）
  - **本地模式 (Local Workflow Mode)**: 无需外部渠道，Agent 之间通过原生的 `agentToAgent` 工具直接在终端内通信。
- 🌐 **Discord 深度优化**: 配置脚本会自动处理 Discord 苛刻的 `<@ID>` 提及规则，并在提示词层面注入“防吞噬警告”。

## 🚀 安装与部署

### 1. 前置准备
- 确保已正确安装并配置了 [OpenClaw CLI](https://docs.openclaw.ai)。
- （可选）提前获取你想要的 Chat Group ID（例如飞书 `oc_...`, Telegram `-100...`）。
- （如果使用 Discord）在 Discord 设置中开启 **开发者模式 (Developer Mode)**，以便后续右键复制机器人的 Client ID。

### 2. 运行安装向导

```bash
git clone git@github.com:shenhao-stu/openclaw-agents.git
cd openclaw-agents

# 推荐：运行交互式配置向导
./setup.sh

# 或者：通过参数跳过提问 (以飞书为例)
# ./setup.sh --mode channel --channel feishu --group-id oc_xxx --require-mention false
# ./setup.sh --mode local
```

*如果你在向导中选择了 **discord**，系统会自动引导你配置每个 Agent 的 Discord Client ID。*

### 3. 重启网关使配置生效
```bash
openclaw gateway restart
```

## 🤖 团队成员

| Agent | 核心职责 | 需要上游谁的数据 | 产出流向下游谁 |
| :--- | :--- | :--- | :--- |
| `main` | OpenClaw 根节点（管理/配置） | 你（用户） | 所有人 |
| `planner` | 统筹规划、跨 Agent 协调 | 所有人 | 所有人 |
| `ideator` | 构思点子、评估新颖性 | `surveyor`, `critic` | `critic`, `coder` |
| `critic` | 把关品味、进行"SHARP"苛刻批评 | `ideator`, `writer` | `planner` |
| `surveyor` | 文献检索、发现研究空白 (Gap) | `scout` | `ideator`, `writer` |
| `coder` | 代码实现、验证实验 | `ideator`, `planner` | `writer` |
| `writer` | 学术撰写、逻辑讲故事 | `coder`, `surveyor` | `reviewer` |
| `reviewer` | 挑毛病、提出修改建议、模拟审稿 | `writer` | `writer` |
| `scout` | 追踪前沿趋势 (arXiv 等) | - | `surveyor`, `planner` |

## 🏗 架构设计：Agent Self-Merge

为了避免暴力覆盖你系统中原有的配置文件，本项目使用了安全的“自我融合（Self-merge）”策略：

1. `setup.sh` 仅在 `openclaw.json` 中配置模型与群组路由。
2. 它会将一份 `BOOTSTRAP.md` 引导文件部署到每个人的工作区。
3. 当 Agent 第一次被唤醒时，它会读取 `BOOTSTRAP.md` 和对应的 `_soul_source.md` 预设，然后智能地将这套多智能体人设合并进它自己的 `SOUL.md` 中。

## 📡 渠道支持

- **Feishu / Slack / Telegram / WhatsApp**: 使用标准的 OpenClaw `bindings` 路由。你可以把他们全塞进一个大群里，也可以通过 `--group-map 'coder=oc_1,writer=oc_2'` 把他们拆分。
- **Discord**: Discord 拥有特殊的纯数字提及系统(`<@ID>`)，因此如果在 `setup.sh` 选择了 Discord，它将自动引导你配置每个 Agent 的 Client ID，并在 Agent 工作区内植入强制性的防格式错乱警告（禁止他们把 ID 放在代码块里）。详见 [Discord 配置完整指南](docs/discord-setup.md)。

## 🛠 高级自定义

### 模型覆盖
```bash
# 为所有 Agent 指定默认模型
./setup.sh --model "github-copilot/gemini-3.1-pro-preview"

# 为不同的 Agent 分别指定模型
./setup.sh --model-map "planner=zai/glm-5,coder=anthropic/claude-3-5-sonnet"
```
