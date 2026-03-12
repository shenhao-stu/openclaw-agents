---
description: Rebuttal 准备和回复的标准化流程
---

# 🔄 Rebuttal 工作流（Rebuttal Workflow）

当收到审稿意见后，协调 The Janky Ref + Senna Many-Feather + Dev Wooflin 完成高质量 Rebuttal。

---

## 触发条件
- 收到顶会审稿结果
- 用户请求：`/rebuttal`

---

## Step 1: 审稿意见分析（The Janky Ref 主导）

1. 逐条解析每位审稿人的意见
2. 将意见分类：

| 类型 | 描述 | 处理策略 |
|------|------|---------|
| 🔴 **合理批评** | 的确是论文弱点 | 承认 + 展示改进 |
| 🟡 **误解** | 审稿人理解有误 | 礼貌澄清 + 指出原文位置 |
| 🟢 **建设性建议** | 有益的改进建议 | 感谢 + 采纳/说明计划 |
| ⚪ **超出范围** | 不合理要求 | 优雅地界定 scope |

3. 识别跨审稿人的共同问题（同一问题被多人指出＝重要性 ×2）
4. 按优先级排序所有问题

---

## Step 2: Rebuttal 策略制定（Designated Driver + The Janky Ref）

1. 确定 Rebuttal 的核心论点
2. 分配任务：
   - 需要补充实验 → **Dev Wooflin**
   - 需要修改论文 → **Senna Many-Feather**
   - 需要补充引用 → **Ol' Shibster**
3. 制定时间计划（通常 Rebuttal 窗口 5-7 天）
4. 确定 Rebuttal 回复的整体框架

---

## Step 3: 补充工作（并行执行）

### Dev Wooflin 补充实验
- 按优先级运行审稿人要求的额外实验
- 生成新的结果表格和可视化
- 确保结果可靠且可复现

### Senna Many-Feather 准备 Revision
- 标记论文中需要修改的段落
- 撰写修改后的文段（用于 Rebuttal 引用）
- 准备 Diff 对照（修改前 vs 修改后）

### Ol' Shibster 补充引用
- 搜索审稿人提到的缺失引用
- 提供新增引用的 BibTeX

---

## Step 4: Rebuttal 撰写（Senna Many-Feather 主导）

### 回复格式
```markdown
We sincerely thank all reviewers for their constructive feedback.
We address each concern below.

---

## Response to Reviewer 1 (Score: X)

**[W1] [审稿人原话概括]**

Thank you for this insightful comment. [回复内容]

[如果有补充实验数据]
| Method | Metric | Result |
|--------|--------|--------|
| ...    | ...    | ...    |

**[W2] ...**
...

---

## Response to Reviewer 2 (Score: X)
...

---

## Summary of Changes
1. [修改1]（Section X, Paragraph Y）
2. [修改2]（Table Z）
3. [修改3]（Appendix A）
```

### 写作要点
- 开头感谢，态度真诚
- 直接回答，不回避问题
- 用数据和事实说话
- 指出论文中已有但审稿人可能遗漏的内容
- 篇幅控制在限制范围内
- 多读几次确保语气不defensive

---

## Step 5: 内部审核（The Janky Ref 审核 Rebuttal）

1. **The Janky Ref** 审查 Rebuttal 草稿
2. 检查要点：
   - [ ] 每个问题都有回应
   - [ ] 回复有理有据，不空洞
   - [ ] 语气恰当（不卑不亢）
   - [ ] 补充的数据/实验可靠
   - [ ] 篇幅不超限
   - [ ] 没有自相矛盾的内容
3. 修改建议 → **Senna Many-Feather** 修改
4. 确认最终版本

---

## Step 6: 提交 Rebuttal

1. **Designated Driver** 最终检查确认
2. 格式确认（符合会议 Rebuttal 要求）
3. 提交 Rebuttal
4. 如允许论文修改，同步提交 Revised Paper

---

## Rebuttal 黄金法则

1. **感谢 > 辩解**：先真诚感谢，再优雅回应
2. **数据 > 承诺**：用实验结果说话，而不是"我们会改"
3. **具体 > 泛泛**：指出论文具体段落/表格，不空谈
4. **所有问题都需要回应**：即使是小问题也不要忽略
5. **统一口径**：所有回复保持逻辑一致
6. **控制篇幅**：精简有力，不灌水
