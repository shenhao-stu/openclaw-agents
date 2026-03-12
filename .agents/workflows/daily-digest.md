---
description: 每日学术情报推送的标准流程
---

# 📰 每日学术速递工作流（Daily Digest）

由 The Librarian 主导的每日信息推送流程。

---

## 触发条件
- 每日定时触发（建议设置：每日上午 9:00）
- 用户手动请求：`/daily-digest`

---

## 执行步骤

### Step 1: 信息采集
The Librarian 从以下来源采集最新论文：
1. arXiv 新论文（cs.CL, cs.AI, cs.LG, cs.MA）
2. Semantic Scholar 关注列表更新
3. 重要研究组最新动态
4. 学术社交媒体热门讨论

### Step 2: 初筛
The Librarian 对采集到的论文进行初步筛选：
- 按关键词匹配度评分
- 按作者/机构重要性评分
- 按与用户研究方向的相关性评分
- 保留 Top 10-15 篇进入精筛

### Step 3: 精筛与摘要
The Librarian 对初筛通过的论文进行精读：
- 阅读 Abstract 和 Introduction
- 提炼一句话摘要
- 评估相关性评分（1-5 ⭐）
- 标注与用户当前项目的关联
- 精选 3-5 篇输出

### Step 4: 生成日报
使用标准日报模板输出，包含：
- 今日要闻（如有重大进展）
- 今日精选论文（3-5 篇）
- DDL 提醒（如有即将到来的会议 DDL）
- 灵感备忘（推送给 Cloud Gazers 的线索）

### Step 5: 预警检查
检查是否有以下情况需要紧急通知：
- 🔴 撞车预警：与正在进行的研究高度相似的论文
- 🟡 技术突破：领域内重大进展
- 🟡 DDL 倒计时：目标会议 DDL 7天/3天/1天提醒

### Step 6: 分发
- 日报推送给用户
- 预警（如有）推送给 Designated Driver
- 灵感线索推送给 Cloud Gazers
- 新的重要论文信息推送给 Ol' Shibster

---

## 周报（Weekly Digest）

每周日额外生成：
1. 本周论文统计汇总
2. 趋势分析（升温/降温方向）
3. 竞争动态更新
4. 对当前研究项目的影响评估
5. 下周关注事项

---

## 自定义配置

用户可通过以下方式自定义推送：
```yaml
# daily_digest_config.yaml
push_time: "09:00"          # 推送时间
max_papers: 5               # 每日最大推送论文数
min_relevance: 3            # 最低相关性阈值（1-5）
include_preprints: true     # 是否包含 arXiv 预印本
language: "zh"              # 摘要语言（zh/en）
weekly_report: true         # 是否生成周报
alert_threshold: 0.8        # 撞车预警相似度阈值
```
