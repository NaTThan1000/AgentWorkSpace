---
schema_version: 1
configured: false
name: 'Knowledge Base'
directory_name: 'Knowledge-released'
purpose: ''
audience: []
topics: []
excluded_topics: []
source_quality: '优先一手、可追溯、论证完整的来源'
default_language: 'zh-CN'
ima_enabled: false
time_sensitive_facts: '需要外部核实并标注核实日期'
---

# KNOWLEDGE_SCOPE · 知识库范围

本文件是显示名、用途和知识范围的 SSOT。`configured: false` 是合法空库状态；首次 Ingest 必须先补齐 `purpose`、至少一个 `topic` 和排除边界，再进行相关性评分。

## 范围解释

- `topics` 决定什么内容具有直接相关性。
- `excluded_topics` 是明确不进入知识库的边界。
- `source_quality` 定义来源门槛，不替代 `../protocols/SCORING_SYSTEM.md` 的逐项评分。
- `ima_enabled` 仅是范围镜像；运行状态以本地 IMA 配置为准。
