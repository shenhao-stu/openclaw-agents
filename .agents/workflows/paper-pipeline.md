---
description: 从零到论文提交的完整流水线，协调所有 Agent 完成一篇顶会论文
---

# 📋 完整论文产出流水线（Paper Pipeline）

本工作流定义了从研究方向到论文提交的完整流程，包含 **Critic 品鉴节点** 和 **主 Agent 审核关卡**。

---

## Phase 0: 项目初始化（Designated Driver 主导）

1. **明确目标**：确认目标会议、DDL、研究范围
2. **启动 The Librarian**：开始监控相关方向的最新论文
3. **评估团队**：检查核心 8 Agent 是否满足需要，识别是否需要追加自定义 Agent
4. **创建项目看板**：初始化进度追踪文档

**输出**: 项目计划文档、时间线、团队配置

---

## Phase 1: 文献调研（Ol' Shibster 主导，1-2 周）

1. **Ol' Shibster** 进行系统文献调研：
   - 收集相关方向近 2-3 年的重要论文
   - 整理方法分类和 SOTA 对比表
   - 识别 Research Gap
2. **The Librarian** 补充最新预印本和趋势信息
3. **Designated Driver** 整合调研结果，确认研究方向

**输出**: 文献调研报告、Research Gap 列表、推荐阅读清单

---

## Phase 2: Idea 生成与筛选（Cloud Gazers 主导，1 周）

1. **Cloud Gazers** 基于调研结果生成 3-5 个候选 Idea
2. 对每个 Idea 进行 ACE 评分（Attractiveness, Contribution, Executability）
3. **Ol' Shibster** 验证候选 Idea 的新颖性（是否已有类似工作）
4. 与用户讨论，选定 Top 1-2 Idea
5. **Cloud Gazers** 精炼 Contribution Statement

**输出**: Idea 评估报告、候选 Research Idea Card、Contribution Statement 初稿

---

## 🎯 Phase 2.5: Idea 品鉴（Tattooed Toni 裁决，3-5 天）

> ⚡ **这是最关键的品味关卡。未通过此关卡，不得进入 Phase 3。**

1. **Tattooed Toni** 接收 Idea Card + ACE 评估，进行 SHARP 品鉴
2. 执行"一句话 Insight Test"和"酒吧测试"
3. 模拟最刁钻审稿人的 Top 3 压力测试
4. 进行"论文灵魂三问"
5. 检测是否命中经典反模式（套壳创新、堆料式、SOTA 刷分等）
6. 给出 Taste 判定：
   - 🏆 **Exquisite**（23-25）→ 全力推进
   - 🟢 **Refined**（18-22）→ 通过，值得投入
   - 🟡 **Raw**（13-17）→ 需要打磨，返回 **Cloud Gazers** 迭代
   - 🔴 **Bland**（<13）→ 另起炉灶，返回 **Phase 2** 重新生成

**通过标准**: SHARP ≥ 18（Refined 及以上）

**如果未通过**:
- Tattooed Toni 给出具体的品味提升方向
- Cloud Gazers 据此迭代打磨 Idea
- 最多 3 轮迭代，仍未通过则上报主 Agent 仲裁

**输出**: SHARP 品鉴报告、最终定稿 Idea Card

---

## Phase 3: 方法设计（Cloud Gazers + Dev Wooflin 协作，1-2 周）

1. **Cloud Gazers** 将 Idea 转化为详细的方法设计
2. **Dev Wooflin** 评估技术可行性
3. 迭代讨论方法细节：
   - 确定核心算法
   - 设计架构图
   - 定义损失函数和训练策略
4. 🎯 **Tattooed Toni** 评估方法优雅性（Parsimony ≥ 4）
5. **Designated Driver** 确认方法方案

**输出**: 方法设计文档、架构图、实验计划

---

## Phase 4: 代码实现（Dev Wooflin 主导，2-4 周）

1. **Dev Wooflin** 搭建项目骨架
2. 实现核心算法模块
3. 实现数据加载和预处理
4. 实现训练和评估流程
5. 进行 Sanity Check（小规模快速验证）
6. **Designated Driver** 进行代码 Review

**输出**: 可运行的代码仓库、Sanity Check 结果

---

## Phase 5: 实验执行（Dev Wooflin 主导，2-3 周）

1. **Dev Wooflin** 运行主实验（与 Baseline 对比）
2. 运行消融实验
3. 运行分析实验（Case Study, Visualization 等）
4. 收集所有实验结果
5. **Designated Driver** 检查实验覆盖度

**输出**: 实验结果报告、数据表格、图表

---

## Phase 6: 论文撰写（Senna Many-Feather 主导，2-3 周）

1. **Senna Many-Feather** 撰写论文大纲
2. 依次撰写各章节：
   - Abstract（最后修改）
   - Introduction（Cloud Gazers 提供 Motivation 素材）
   - Related Work（Ol' Shibster 提供草稿）
   - Method（Dev Wooflin 提供技术细节）
   - Experiments（Dev Wooflin 提供结果数据）
   - Conclusion
3. 制作图表（架构图、结果可视化）
4. 整理参考文献
5. 🎯 **Tattooed Toni** 评估叙事品质和记忆点（至少 1 个明确记忆点）

**输出**: 论文初稿（LaTeX）

---

## Phase 7: 内部审稿与修改（The Janky Ref + Tattooed Toni + Senna Many-Feather 迭代，1-2 周）

1. **The Janky Ref** 进行第一轮全面审稿（技术维度）
2. 🎯 **Tattooed Toni** 进行品质终审（品味维度）
3. **Senna Many-Feather** 根据 The Janky Ref + Tattooed Toni 的意见修改论文
4. **Dev Wooflin** 补充实验（如果 The Janky Ref/Tattooed Toni 要求）
5. **The Janky Ref** 进行第二轮审稿
6. 重复直到 The Janky Ref 给出 Accept + **Tattooed Toni 确认"值得投"**

**输出**: 修改后的论文、审稿报告、品质终审报告

---

## Phase 8: 提交准备（Designated Driver 统筹，2-3 天）

1. **The Janky Ref** 进行最终 Camera-Ready 检查
2. 格式合规性确认（页数、字体、匿名性）
3. 准备 Supplementary Material
4. 完成 Submission Checklist
5. 🔐 **主 Agent 最终审核**：Phase Gate Audit
6. **Designated Driver** 确认一切就绪
7. 提交！🎉

**输出**: 最终论文包（Main Paper + Appendix + Supplement）

---

## 时间预算参考（以 3 个月为例）

```
Week 1-2:   Phase 1 (文献调研)
Week 2-3:   Phase 2 (Idea 生成)
Week 3:     Phase 2.5 (🎯 Tattooed Toni 品鉴) ← 关键节点
Week 3-4:   Phase 3 (方法设计)
Week 4-7:   Phase 4 (代码实现)
Week 7-9:   Phase 5 (实验执行)
Week 9-11:  Phase 6 (论文撰写)
Week 11-12: Phase 7 (审稿修改 + 品质终审)
Week 12-13: Phase 8 (提交准备 + Pack Leader审核)
```

> ⚠️ 实际进度应根据 DDL 倒推调整。如果 Phase 2.5 品鉴未通过需要迭代，后续阶段时间相应压缩。
