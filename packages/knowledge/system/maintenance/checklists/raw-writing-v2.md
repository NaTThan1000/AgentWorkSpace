# 消化稿写作与独立审核说明

先完整读取 [RAW_STANDARD_V2](raw-standard-v2.md)，规则修订 `core-semantic-20260910`。本说明用于写作、复核和回测，不另设尺度。

## Codex + GPT 角色路由

当前 Ingest 路由由 `system/protocols/INGEST_WRITER_ROUTING.md` 统一规定：Raw/Wiki 正文的初写、补写和广泛返修使用 `gpt-5.6-luna + max` 写作子 agent；每批 Raw Stage1 的独立语义复核默认由一个固定的 `gpt-5.6-terra + high` 主复核子 agent 执行。明确缺陷最多两轮定点修复与同一 Terra targeted 复验；只有 targeted 结果含 uncertain，或有来源依据的 R01-R05 finding 标为 `semantic_dispute`，才升级为 `gpt-6-astra + low`。该路由不改变本文件与 RAW_STANDARD_V2 的语义尺度，也不允许写作者自审自批。

语义复核 agent 只对照冻结 source manifest、Clipping、Raw 和审核合同向控制器指定的 `report_path` 输出语义报告；不得直接改 Raw，也不得手工生成 request、host、provenance 或 receipt。调度者先调用 `ingest-control.ps1 -Action prepare-raw-review` 分配模型、轮次、冻结请求和脚本生成的报告骨架；写完先运行 `preflight-raw-review` 一次收集机械错误，再调用 `complete-raw-review -AgentId <实际ID>`。小而明确的 finding 可带 `replacement_text`，由 `apply-review-repairs` 按单一、不重叠 raw range 机械应用；需重组论证时由 Luna max 返修。

## 写作示例与取舍

合成原材料：团队聚餐时聊到旧关卡追求漂亮闪光，试玩者却把无伤闪光误认为命中，于是先定义要识别的事件，再选表现通道，最后放到竞争信息中验证。同一 60 fps 设备上，命中显示延迟由 6 帧变为 3 帧；12 位初次接触者中 7 位自述更易辨认，但没有隔离音效变化，多目标和光敏条件尚未测试。

合格消化：“旧方案的无伤闪光被误认成命中，说明美观不等于信息准确。团队因此调整顺序：先明确玩家要识别的事件，再选择表现通道，最后在其他信息同时出现时验证。

同一 60 fps 设备上，命中显示延迟由 6 帧降至 3 帧；12 位初次接触者中 7 位自述更易辨认。由于未隔离音效变化，也未测试多目标和光敏条件，不能将这一观察推广到所有场景。”

聚餐场景可删，因为它不解释误判机制或测试结果；推理、数据与限制不能删成“事件优先，反馈更快，玩家更满意”。

神话来源可把长故事组织为“国王违背献祭承诺 → 神罚促成异类出生 → 怪物被关入迷宫”，再解释它为何关联“非自然造物、迷宫怪物”的形象。争位过程、道具制作、英雄脱身等支线，若不承担本文兵种文化论证，可以省略；若文章正用道具说明技术原型，则该细节必须保留。不是按故事或字数一刀切。

## 独立审核合同

审核者必须独立于写作者，只读请求列出的标准、来源、Raw 和必要定位/媒体材料；不读作者对话、自评或期望结果。不修改库内容、门禁或用户决定。每批第一个 Terra 全文审核建立主复核上下文，后续全文审核与 targeted 复验复用该上下文；只有 Astra escalation 使用新的独立上下文。缺少真实独立运行时不能自动通过。

当使用默认 Terra high 或升级 Astra low 路由时，模型配置只决定执行者，不降低逐单元证据要求。`review_scope=full_text_bidirectional` 时审核者执行完整双向 source→raw / raw→source 合同；`review_scope=targeted_recheck` 时只复验 request 列出的变更 Raw 单元、相邻上下文、关联来源单元、`target_core_claims` 和篇章判断，控制器再按上一轮收据、内容指纹和行号重映射编译全文收据。targeted 由同一主复核者执行，可读取控制器提供的 baseline finding 与目标邻域；旧裁决仍只由控制器按哈希绑定后复用。不能自行扩大或缩小 request 的目标集合，也不能重写已复用的裁决。

1. full request 完整阅读全部来源与 Raw，确认 manifest 无漏行，审查跨章限定，并列出全部 `core_claims`：每项 id、meaning、source_ids、raw_ranges。targeted request 只重审 `target_core_claims` 并在报告 `core_claims` 中提交这些 ID 的当前裁决；控制器负责编译未受影响的旧观点。真实缺失的观点可用空范围，须同时报 R01/R07 finding，不能伪造位置。
2. full request 中每个 source unit 恰好一条 source_checks、每个 raw unit 恰好一条 raw_checks；targeted request 只对其中列出的目标单元各写一条。控制器拒绝遗漏、额外单元和无法由旧收据稳定映射的复用项。不要以“话题覆盖”代替含义核对。
3. policy：required / structure / omit_metadata / omit_duplicate / omit_nonsemantic_media / omit_context / media。structure 仅无新增含义的标题；重复须 duplicate_of 指向已完整保留的 required 单元。metadata 与非语义媒体有具体理由。
4. required 的 elements 逐个列出实际 source_quote、status、raw_ranges。完整项无需重复 meaning 或“已保留”reason；partial/missing/distorted/uncertain 必须写具体 reason，并一律阻断。混合段落的非必要要素可为 not_applicable，但须 `retention:"context"`、空 raw_ranges 及 `omission:{claim_ids:[相关核心观点ID],reason:"删去后为何不损害观点及论证"}`；这类省略可用 meaning 补充压缩后的含义，不写时以 source_quote 作为含义。其余必要要素不得随之豁免。whole-unit omit_context 同样须 omission，不用空泛“不重要”蒙混。
5. media 的 marker_only 必须定位实际“未转录”；若仅是非必要视觉细节，增加 `nonessential:{claim_ids,reason}`，解释已保留哪些核心知识、为何该视觉细节不影响理解。否则为 media_limited。需要的图已转为文字可按 required 判断；重复图可指向文字；不猜读模糊图。
6. raw_checks 为 id、status（supported / unsupported / uncertain）、source_ids；supported 无需重复 reason，unsupported / uncertain 必须解释，反查正文、标题主张与评价是否有来源。合理结构标题不等于新增事实。
7. 独立判断 style、cross_section，禁止字数/列表比例代替文风判断。findings 每项含 rule（R01–R13）、source_ids、raw_ranges、detail。删减损害推理/证据时必须明确报告，不能为了 pass 把它改称上下文。

## 报告与证据

优先从 `prepare-raw-review` 返回的 `report_template_path` 填写，ID、source_quote、基础对象和请求哈希由脚本生成。提交前运行 `preflight-raw-review`，一次修完返回的全部机械错误，再调用 complete。

报告 schema_version 为 2，必须包含 `ruleset:"core-semantic-20260910"`、request_sha256、真实 reviewer_context_id、core_claims、manifest_review、source_checks、raw_checks、style、cross_section、findings。

manifest_review / style / cross_section 均有 status（complete / partial / uncertain）；complete 无需重复 reason，partial / uncertain 必须解释，style 另含 findings 数组。source_checks 的 complete 同样无需 reason。所有行号为一基、闭区间二维数组；source_quote 必须确实出现在该 source unit 中。引用 claim_ids 必须来自本报告 core_claims。不能用单个完整段落引文掩盖第二个必要案例、数字或限定。

调度者把真实 Agent ID 交给 `complete-raw-review`；控制器保存上下文 ID、调度窗口、模型路由与 provenance，并绑定请求、报告和回执哈希。host-record 仍只是宿主观测，JSON 不证明语义或独立性；禁止伪造调用记录。回测与 Stage1 调用同一 evaluator，不沿用旧规则通过结果。
