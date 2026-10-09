# RUNTIME_ROUTING · 按任务读取

| 请求 | 唯一入口 | 边界 |
|---|---|---|
| 专业问答/查阅 | QUERY_PROTOCOL.md | 核心Wiki读透，补充按需；不修改正文和索引 |
| 消化来源 | INGEST_PROTOCOL.md | 未限定时标准interactive；显式自动deferred |
| 健康检查/Lint | ../maintenance/checklists/knowledge-health-check.md | 统一runner默认只报告，修复独立有范围 |
| 状态/恢复批次 | ../maintenance/checklists/ingest-control.ps1 status | 当前run/registry为准，历史final review保留 |
| 初始化 | ../maintenance/SETUP.md | dry-run后显式Apply |

用户明确来源权限优先；准备请求不等于已读证据。复杂分析的专业工作流由宿主接入，不在此包启用专家运行时。
