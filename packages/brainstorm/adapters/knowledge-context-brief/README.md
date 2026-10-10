# Knowledge ContextBrief Adapter

Adapter ID=`knowledge-context-brief`，ready；九字段 ContextBrief 结构来源于 Knowledge/system/integrations/GAME_ANALYSIS_DECISION.md（context-brief-game-analysis-decision-handoff-v1），普通检索执行遵守 Knowledge/system/protocols/QUERY_PROTOCOL.md。这是沿用材料格式，不启动旧版 GameAnalysisDecision 流程；Brainstorm 的 GameAnalysisDecision 路由使用本仓现行 v2 adapter。

## When and how

遇到事实缺口、候选同质化、需要反例或已定条件核查时，在现有授权内按需调用。无需固定等第一轮发散结束或用户再发口令。先保留原始输入/独立想法，防止参考材料覆盖来源；明确当前是事实查证还是创意刺激。

1. Agent 复用 session、候选、决定和证据装配 task、target_experience、target_player、current_loop_or_system、project_stage、constraints、observed_symptoms、locked_decisions、available_evidence。只填相关已知内容，未知为 `-`；不让用户重复填表。
2. new-knowledge-context-brief 只建立请求材料，返回 context_prepared=true / query_executed=false。生成的 task 来源栏还需 Agent 回链到实际 RAW/IDEA/DEC；骨架不是已验证请求。
3. 按 Knowledge 当前 Query 协议判断本题需要及各来源权限，调用 `Knowledge/system/query/query-evidence.mjs` 的 discover/read（可用同一模块的 JS API）：核心 Wiki 读透，补充完整章节按缺口展开，决定性命题回查 raw。工具返回真实内容、版本和范围；候选、hash 或 `evidence_consistent` 不证明已正确使用。复用检查当前对象、范围和版本；预算耗尽仍有关键缺口时如实说明。Web 独立按时效需要及用户权限处理；领域原则保留稳定 ID，按需补充，不代替 Wiki/原文。
4. 将实际结果和适用限制写入 Evidence Annex，知识结果为 knowledge，联网结果为 web；独立来源和同源转载分开。每条 Finding 要有准确文件/来源指针，Limits 写对象/阶段/证据不足。
5. Result Link 从 pending 变 completed 仅在真实 Query 后，引用新增/实际使用 EVID；Notes 包含查询范围、未读/不可用和结果如何影响候选。完成查询也可能无相关命中，此时记录“无相关来源”的 knowledge Evidence 及实际搜索范围，不伪造支持结论。
6. 对照原候选记录支持、挑战或变形，不自动淘汰、不替用户采用。重要分析走 GameAnalysisDecision v2，普通 Knowledge Query 不默认经由 GameAnalysisDecision。

## Failure and boundary

Knowledge 不可用时 availability/result 均 unavailable，Evidence IDs 为 `-`，Notes 写原因；继续授权内独立工作或其他来源。pending 不可挂结果 Evidence。

validate-knowledge-context-brief 检查九字段、既有来源和结果引用；不能证明查询实际发生或材料真的支持结论。执行证据必须是实际读取记录与可复核来源。仅校验/生成不可报告调用完成。

Clippings、raw/raw-sources、wiki 只读，Query 不写入、消化或晋升内容。当前兴趣不变长期用户画像。Knowledge 负责检索规则，Brainstorm 保有创意、会话和决定所有权。
