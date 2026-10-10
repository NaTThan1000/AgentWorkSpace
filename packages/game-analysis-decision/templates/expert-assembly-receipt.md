# 实际专业装配记录（可选）

仅在真实独立协作、可恢复装配或明确审计需要时产生；普通任务不创建 not_requested 文件。直接复用 Provider 返回的选择与来源状态，用户不需阅读多份角色报告。

- 本轮问题、选择的具体专业内容、版本及为何值得使用。
- 实际使用的是一个 Agent 的专业配置，还是有独立上下文的分支；不要凭角色名自称独立。
- 读取了哪些必要来源、支持范围和降级；source_plan 不等于已经读过。
- 额外读取与协作的实际消耗、停止条件；测量不可得就标未知。
- 如何改变了判断；没有增益就不扩大装配。

## Group provenance（仅当 Knowledge Query 使用或显式未提供时记录）

- evaluated_groups: `<canonical IDs | 未读取 | not_provided>`
- selected_via_group: `<Group → Wiki；无则写无>`
- skipped_via_group: `<Group → Wiki + 原因；无则写无>`
- coverage_axes / raw_expansion: `<Query 收据实际值；无则写无>`
- role_effect: `none`（Group 不新增 role / Team，不改变 Query level、预算或 raw 权限）

> 此段只消费既有 Knowledge Query 收据。GameAnalysisDecision 不扫描 Group、不推断成员、不重排候选；若跨 Provider 保留逐候选 provenance 的需求出现，另开 schema 升级决策。
> `group_provenance_mode: consume_only`; `group_algorithm: not_reimplemented`.
