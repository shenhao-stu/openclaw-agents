# Discord 配置完整指南

本指南详细说明如何将 OpenClaw Agents 部署到 Discord 服务器，包括 Bot 创建、权限配置、多 Agent 协作设置。

## 目录

- [前置要求](#前置要求)
- [第一步：创建 Discord 应用](#第一步创建-discord-应用)
- [第二步：获取必要 ID](#第二步获取必要-id)
- [第三步：安装 OpenClaw Agents](#第三步安装-openclaw-agents)
- [第四步：配置多 Agent 路由](#第四步配置多-agent-路由)
- [第五步：启动 Gateway](#第五步启动-gateway)
- [常见问题](#常见问题)

---

## 前置要求

1. **OpenClaw CLI 已安装**

```bash
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

验证安装：

```bash
openclaw --version
```

2. **Discord 账户** — 需要 Discord 账户来创建 Bot
3. **服务器管理权限** — 在目标 Discord 服务器拥有管理权限

---

## 第一步：创建 Discord 应用

### 1.1 访问开发者门户

访问 [Discord Developer Portal](https://discord.com/developers/applications)

### 1.2 创建新应用

1. 点击右上角 **"New Application"**
2. 输入应用名称（例如：`OpenClaw-Bot`）
3. 点击 **"Create"**

### 1.3 创建 Bot 用户

1. 左侧菜单选择 **"Bot"**
2. 点击 **"Add Bot"**
3. 确认创建

### 1.4 获取 Bot Token

在 Bot 页面：

1. 点击 **"Reset Token"** 生成新 Token
2. **立即复制并保存** — Token 只显示一次
3. Token 格式：`MTk4NjIyNDgzNDc2Nzg2NjQw.xxxxxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxx`

> ⚠️ **安全警告**：Token 等同于 Bot 密码，绝不要提交到公开仓库或分享给他人。

### 1.5 配置 Bot 权限

#### Privileged Gateway Intents

在 Bot 页面底部，启用以下 Intents：

| Intent | 必需 | 说明 |
|--------|------|------|
| **PRESENCE INTENT** | ❌ 可选 | 获取成员在线状态 |
| **SERVER MEMBERS INTENT** | ✅ **必需** | 读取服务器成员列表（用于 @mention 解析） |
| **MESSAGE CONTENT INTENT** | ✅ **必需** | 读取消息内容 |

保存更改。

---

## 第二步：获取必要 ID

### 2.1 获取 Guild ID（服务器 ID）

1. 打开 Discord 客户端
2. 进入 **设置** → **高级** → 启用 **"开发者模式"**
3. 右键点击目标服务器名称
4. 选择 **"复制服务器 ID"**

格式：`123456789012345678`（18-19 位数字）

### 2.2 邀请 Bot 到服务器

#### 方式 A：使用官方邀请链接生成器

1. 在 Developer Portal，左侧选择 **"OAuth2"** → **"URL Generator"**
2. Scopes 勾选：`bot`、`applications.commands`
3. Bot Permissions 勾选：
   - ✅ Send Messages
   - ✅ Send Messages in Threads
   - ✅ Embed Links
   - ✅ Attach Files
   - ✅ Read Message History
   - ✅ Mention Everyone
   - ✅ Add Reactions
4. 复制生成的邀请链接
5. 在浏览器打开链接，选择服务器并授权

#### 方式 B：手动构建邀请链接

```
https://discord.com/api/oauth2/authorize?client_id=YOUR_CLIENT_ID&permissions=277025508352&scope=bot%20applications.commands
```

将 `YOUR_CLIENT_ID` 替换为你的应用 Client ID（在 General Information 页面）。

### 2.3 获取频道 ID（可选）

如果需要绑定特定频道：

1. 右键点击频道名称
2. 选择 **"复制频道 ID"**

---

## 第三步：安装 OpenClaw Agents

### 3.1 克隆仓库

```bash
git clone https://github.com/shenhao-stu/openclaw-agents.git
cd openclaw-agents
```

### 3.2 运行安装脚本

#### 选项 A：交互式安装（推荐）

```bash
chmod +x setup.sh
./setup.sh
```

按提示选择：
- Deployment mode: `channel`
- Channel type: `discord`
- Group ID: 输入你的 Guild ID

#### 选项 B：命令行参数安装

```bash
./setup.sh --mode channel --channel discord --group-id YOUR_GUILD_ID
```

示例：

```bash
./setup.sh --mode channel --channel discord --group-id 123456789012345678
```

### 3.3 配置 Bot Token

编辑 `~/.openclaw/openclaw.json`：

```json
{
  "channels": {
    "discord": {
      "token": "MTk4NjIyNDgzNDc2Nzg2NjQw.xxxxxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxx",
      "guildId": "123456789012345678",
      "groupPolicy": "open"
    }
  }
}
```

---

## 第四步：配置多 Agent 路由

### 4.1 为什么需要配置路由？

Discord 的 @mention 机制与飞书、Telegram 不同：

| 平台 | Mention 格式 | 特殊要求 |
|------|-------------|---------|
| 飞书 | `@planner` | 无 |
| Telegram | `@planner` | 无 |
| Discord | `<@123456789012345678>` | **必须使用数字 ID** |

在 Discord 中：
- `@planner` 只是纯文本，不会触发通知
- `<@123456789012345678>` 才是真正的 mention

### 4.2 获取 Bot Client ID

在 Discord Developer Portal：

1. 选择你的应用
2. General Information 页面
3. 复制 **"Application ID"**（也叫 Client ID）

### 4.3 使用 Python 配置脚本

仓库提供了 `setup_discord.py` 自动配置工具：

```bash
python3 setup_discord.py
```

脚本会提示你输入每个 Agent 的 Client ID。如果你还没有，可以先跳过，稍后编辑配置文件。

### 4.4 手动配置 mentionPatterns

编辑 `~/.openclaw/openclaw.json`，为每个 Agent 添加 `mentionPatterns`：

```json
{
  "agents": {
    "list": [
      {
        "id": "planner",
        "name": "🧠 Planner",
        "groupChat": {
          "mentionPatterns": [
            "<@YOUR_PLANNER_CLIENT_ID>",
            "@planner",
            "@Planner",
            "planner"
          ],
          "historyLimit": 50
        }
      },
      {
        "id": "coder",
        "name": "💻 Coder",
        "groupChat": {
          "mentionPatterns": [
            "<@YOUR_CODER_CLIENT_ID>",
            "@coder",
            "@Coder",
            "coder"
          ],
          "historyLimit": 50
        }
      }
    ]
  }
}
```

> 📝 **关键**：`<@数字ID>` 必须放在 `mentionPatterns` 的**第一位**，这样 OpenClaw 才能正确识别 Discord mention。

---

## 第五步：启动 Gateway

### 5.1 启动服务

```bash
openclaw gateway
```

看到类似输出表示成功：

```
✅ Discord gateway connected
🧠 Planner ready
💻 Coder ready
...
```

### 5.2 测试 Agent 响应

在 Discord 服务器中：

```
@planner 请分解这个任务
```

应该看到 Planner Agent 回复：

```
🧠 Planner: 好的，我来分解这个任务...
```

---

## ⚠️ Discord Mention 极度重要警告

### 问题：Markdown 表格中的 Mention 不生效

**错误做法**：

```
我指派了以下任务：

| Agent | 任务 |
|-------|------|
| <@123456789012345678> | 设计架构 |
| <@987654321098765432> | 编写代码 |
```

**结果**：Discord 会把表格中的 `<@数字ID>` 渲染为纯文本，**对方收不到任何通知**。

### 正确做法：在回复末尾添加纯文本 Mention

```
我指派了以下任务：

| Agent | 任务 |
|-------|------|
| Planner | 设计架构 |
| Coder | 编写代码 |

<@123456789012345678> 和 <@987654321098765432>，请立刻开始执行上述任务！
```

### 原理

Discord 的消息解析机制：
- Markdown 表格、代码块内的内容 → **纯文本**
- 消息末尾的纯文本 → **可解析的 mention**

### 配置自动注入警告

`setup_discord.py` 会自动在每个 Agent 的 `_soul_source.md` 中注入警告：

```markdown
## [ Discord 通信极度重要警告 ]
🚨🚨🚨 极度重要警告 🚨🚨🚨
当你需要指派任务给其他 Agent 时，你 **绝对不能** 只把他们的 `<@数字ID>` 写在 Markdown 表格或者代码块 (```) 里！
如果你把 `<@数字ID>` 放在表格里，Discord 系统就会判定那是普通文本，**对方根本收不到任何消息，永远不会回复你！**
你必须在回复的最后，像人类一样，用一段没有任何格式的纯文本直接说：
「<@1478488144499183749> 和 <@1478488715226648770>，请立刻开始执行上述任务！」
如果不这么做，你的任务指派将 **必定失败**。
```

---

## 配置文件完整示例

### openclaw.json（Discord 多 Agent）

```json
{
  "channels": {
    "discord": {
      "token": "MTk4NjIyNDgzNDc2Nzg2NjQw.xxxxxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxx",
      "guildId": "123456789012345678",
      "groupPolicy": "open",
      "groups": {
        "123456789012345678": {
          "requireMention": true
        }
      }
    }
  },
  "agents": {
    "defaults": {
      "model": "zai/glm-5"
    },
    "list": [
      {
        "id": "planner",
        "name": "🧠 Planner",
        "groupChat": {
          "mentionPatterns": [
            "<@PLANNER_CLIENT_ID>",
            "@planner",
            "@Planner",
            "planner"
          ],
          "historyLimit": 50
        },
        "subagents": {
          "allowAgents": ["*"]
        }
      },
      {
        "id": "ideator",
        "name": "💡 Ideator",
        "groupChat": {
          "mentionPatterns": [
            "<@IDEATOR_CLIENT_ID>",
            "@ideator",
            "@Ideator",
            "ideator"
          ],
          "historyLimit": 50
        }
      },
      {
        "id": "critic",
        "name": "🎯 Critic",
        "groupChat": {
          "mentionPatterns": [
            "<@CRITIC_CLIENT_ID>",
            "@critic",
            "@Critic",
            "critic"
          ],
          "historyLimit": 50
        }
      },
      {
        "id": "surveyor",
        "name": "📚 Surveyor",
        "groupChat": {
          "mentionPatterns": [
            "<@SURVEYOR_CLIENT_ID>",
            "@surveyor",
            "@Surveyor",
            "surveyor"
          ],
          "historyLimit": 50
        }
      },
      {
        "id": "coder",
        "name": "💻 Coder",
        "groupChat": {
          "mentionPatterns": [
            "<@CODER_CLIENT_ID>",
            "@coder",
            "@Coder",
            "coder"
          ],
          "historyLimit": 50
        }
      },
      {
        "id": "writer",
        "name": "✍️ Writer",
        "groupChat": {
          "mentionPatterns": [
            "<@WRITER_CLIENT_ID>",
            "@writer",
            "@Writer",
            "writer"
          ],
          "historyLimit": 50
        }
      },
      {
        "id": "reviewer",
        "name": "🔍 Reviewer",
        "groupChat": {
          "mentionPatterns": [
            "<@REVIEWER_CLIENT_ID>",
            "@reviewer",
            "@Reviewer",
            "reviewer"
          ],
          "historyLimit": 50
        }
      },
      {
        "id": "scout",
        "name": "📰 Scout",
        "groupChat": {
          "mentionPatterns": [
            "<@SCOUT_CLIENT_ID>",
            "@scout",
            "@Scout",
            "scout"
          ],
          "historyLimit": 50
        }
      }
    ]
  }
}
```

---

## 常见问题

### Q: Bot 没有回复消息

**检查清单**：

1. Bot Token 是否正确配置
2. Gateway 是否启动（`openclaw gateway`）
3. `requireMention` 是否为 `true`（需要 @mention 才会回复）
4. Bot 是否有 **Read Message History** 权限
5. **Message Content Intent** 是否启用

### Q: Agent 之间无法互相通知

**原因**：Mention 被放在 Markdown 表格或代码块中

**解决**：
1. 确保 Agent 的 `_soul_source.md` 包含 mention 警告
2. 在消息末尾添加纯文本 mention

### Q: 如何获取 Channel ID？

1. 启用开发者模式（设置 → 高级）
2. 右键点击频道 → 复制频道 ID

### Q: 如何限制 Bot 只响应特定频道？

修改 `openclaw.json`：

```json
{
  "channels": {
    "discord": {
      "groupPolicy": "allowlist",
      "groups": {
        "CHANNEL_ID_1": {},
        "CHANNEL_ID_2": {}
      }
    }
  }
}
```

### Q: 如何调试 Gateway 问题？

查看日志：

```bash
openclaw gateway --verbose
```

或查看 OpenClaw 日志文件：

```bash
tail -f ~/.openclaw/logs/gateway.log
```

### Q: Bot 权限错误怎么办？

重新生成邀请链接，确保包含以下权限：
- Send Messages
- Send Messages in Threads
- Embed Links
- Attach Files
- Read Message History
- Mention Everyone
- Add Reactions

计算权限值：[Discord Permissions Calculator](https://discordapi.com/permissions.html)

---

## 下一步

- 📖 阅读 [OpenClaw 官方文档](https://docs.openclaw.ai)
- 🤖 了解 [多 Agent 协作机制](https://docs.openclaw.ai/concepts/multi-agent)
- 📋 尝试 [工作流模板](../.agents/workflows/)

---

## 相关链接

- [Discord Developer Portal](https://discord.com/developers/applications)
- [Discord API 文档](https://discord.com/developers/docs/intro)
- [OpenClaw Discord 频道文档](https://docs.openclaw.ai/channels/discord)

---

<p align="center">
  <strong>🎉 祝你使用愉快！</strong>
</p>
