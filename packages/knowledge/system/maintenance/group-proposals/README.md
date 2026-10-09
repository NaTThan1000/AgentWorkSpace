# Wiki Group Proposals

本目录保存尚未成为运行时 Group 的提案、全库发现收据和人工裁决材料。Proposal 可由单篇 Wiki 提出，但不能因为文件存在而自动创建 Group 或改写 Wiki frontmatter。

每份 Proposal 的 frontmatter 必填：`id`、`name`、`kind`、`aliases`、`entry_basis`、`query_use_cases`、`discovery_signals`、`exclusion_signals`、`coverage_axes`、`approval`。其中：

- `entry_basis` 是 `semantic_standard` 或 `relational_value`，也可同时列出二者。
- `query_use_cases` 至少一项，是两个成立入口共同的必要条件。
- `approval` 初始为 `pending`；只有制作人明确批准后才可改为 `approved`。
- `discovery_signals` 和 `exclusion_signals` 只用于低成本筛查，不能直接判定成员。

Proposal 正文必须说明定义、纳入边界、排除边界、反例、语义或关系依据、覆盖维度、初始成员裁决、未决项与 `review_when`。全库扫描收据使用同 ID 与日期，放在 `system/maintenance/group-reviews/`。
