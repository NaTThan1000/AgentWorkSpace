# Raw v2 审核报告字段速查

这是现有 `raw-quality.mjs` 合同的字段说明，不改变 RAW_STANDARD_V2 的语义尺度。审核者在落盘前据此自检，不能由生产者代改语义判断。

- 现行 ruleset 为 core-semantic-20260910；报告必须列出 core_claims，规则更改后不沿用旧请求和旧报告。
- `source_checks.status` 与 `elements.status` 不是同一枚举。required 的必要要素允许 complete / partial / missing / distorted / uncertain；混合段落中的非必要上下文可以 not_applicable，但必须 retention=context、空范围及关联核心观点的 omission 理由。整段上下文用 omit_context。marker_only 仅用于独立 media 单元。
- `policy=structure` 仅允许 manifest 的 kind=heading，且 status=complete。粗体段标题即使视觉像标题，只要 manifest 是 paragraph，仍按 required 记录实际含义和定位；不得把普通转场/摘要当结构豁免。
- Raw 不嵌图；未读图不猜图义。media/marker_only 必须定位实际未转录文字；仅非必要视觉细节可用 nonessential 的 claim_ids 与具体 reason 说明，检查器在通过回执中仍保留 media_disclosures。
- manifest_review、style、cross_section 只允许 complete / partial / uncertain。确认失真可写 partial，并在 findings 说明，不能使用 distorted 作为篇章级状态。
- missing 要素的 raw_ranges 必须为空；partial/distorted/complete 必须定位实际 Raw 行，不能用原文行号。
- source_quote 必须是所属 source unit 的真实连续子串；不能用省略号拼接几段话。
- 精简格式下，complete 的 source_checks、elements、raw_checks、manifest_review、style、cross_section 不重复写 reason；complete element 不重复写 meaning。异常、不确定与省略仍必须给出具体理由，不能用精简格式隐藏问题。
- 明确遗漏、无来源新增、格式或确定性失真使用 `resolution:"repair"` 或省略 resolution；只有有来源定位的 R01-R05 解释分歧可写 `resolution:"semantic_dispute"`。任一 uncertain 也进入争议升级判断；R06-R13 不能借此升级 Astra。
- 每个 source unit 和 Raw unit 恰好一条，不能遗漏、重复或添加不在请求中的 ID。
- 修订保存新文件，保留旧失败；请求、报告和真实宿主调用分别绑定哈希。字段合法不等于内容正确。

开发校准和历史回测均实际触发过上述枚举/结构拒绝。此说明用于减少模型交付错误；检查器仍严格拒绝，不自动放宽或把错误枚举转换成通过。
