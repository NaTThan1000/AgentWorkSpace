# Ingest 写作与语义复核执行路由

本文由 INGEST_PROTOCOL 引用，规定写作职责，不改变内容标准、审核闸门或阶段状态。适用于标准与自动消化，以及返修和回测中的正文重写。

## Codex + GPT 默认配置

用户已确认：Codex 宿主使用 GPT 系列模型执行消化时，每批默认复用一个 `model=gpt-5.6-luna`、`reasoning_effort=max` 的内容写作子 agent，依次承担 Raw 与 Wiki 正文生成或返修；Raw 的独立语义复核由每批一个 `model=gpt-5.6-terra`、`reasoning_effort=high` 主复核子 agent 统一执行。明确遗漏、无来源新增、格式或确定性失真继续由 Luna 定点返修、同一 Terra 会话 targeted 复验；只有 Terra targeted 仍为 `uncertain`，或把有来源依据的 R01-R05 解释分歧标为 `semantic_dispute`，才升级为 `model=gpt-6-astra`、`reasoning_effort=low` 的 fresh-context 复核。升级不是常规复核步骤。这是当前 Codex + GPT Ingest 路由，不是对模型普遍能力的结论，也不代表主会话切换模型。其他宿主或非 GPT 环境沿用协议的能力选择规则。

| 工作 | 执行者 |
|---|---|
| Stage1 Raw 初写、补写、返修 | 每批一个 Luna max 内容写作子 agent；默认与 Stage3 复用同一会话 |
| Stage1 Raw 独立语义复核（默认） | 每批一个 Terra high 主复核子 agent；批内保持同一上下文 |
| Stage1 经 Terra targeted 后仍存在有证据的语义争议或 uncertain | Astra low fresh-context 升级复核子 agent |
| Stage2 Wiki 归属、增量、冲突、未消费规划 | 主会话 |
| Wiki 正文补充、融合、返修（控制器 Stage3 写入环节） | 复用本批 Luna max 内容写作子 agent |
| 来源身份、评分、媒体边界、Wiki 归属/冲突、辅助台账、审核包、检查器、回测组织、维护、状态和 Git | 主会话 |

用户所说的 Stage2 补充 Wiki 是业务上的 Wiki 消化环节；不得在控制器 Stage2 规划闸门通过前写入 Wiki，也不能漏掉 Stage3 实际正文写作。Raw v2 的独立全文语义审核是必需门，不因 `ingest-semantic-review-policy.json` 的四阶段可选语义模式为 disabled 而关闭；两者使用不同证据合同，不能混用。写作者不得自审自批，主会话普通回读也不能冒充独立审核。语义复核子 agent 专注语义审计，不直接覆盖正文；小而明确的问题可提供绑定单一区间的 `replacement_text`，由控制器机械应用，再由同一主复核者验证变更邻域。

## Raw Stage1 语义复核路由

- 每份由 Luna max 写成的 Raw，均须由本批同一个 Terra high 主复核者独立回读 `Clipping → manifest → Raw`，输出现行 `raw-quality.mjs` 合同所需的语义证据；不得读取写作者自评。主复核者在批内保持上下文连续，targeted 复验允许读取控制器生成的目标包和自己上一轮 finding。
- 以下情况要求 Terra r1 明确提出定点返修或阻断：来源存在前/后者等未消歧指代且不能由确定性证据消歧；人物—对象—动作主体在关键结论处仍易错配；连续因果/时间链跨多个转折且影响结论；数字、比例、时间点或适用条件存在相互冲突；必要媒体未转录或 manifest 为 `uncertain/media_limited`。Raw 实际修改后由 Terra targeted 复核。targeted request 只包含变更 Raw 单元、相邻上下文、关联来源单元和篇章判断；未变裁决由控制器按上一轮哈希与内容指纹复用并编译为全文收据。明确缺陷允许最多两轮 Luna 定点返修与 Terra targeted 复验；第二轮仍有明确缺陷就阻断。只有 targeted 结果含 uncertain，或有来源依据的 R01-R05 finding 明确标为 `semantic_dispute`，才触发一次 Astra low。
- 正常情形不追加 Astra。升级时重点挑战控制器列出的相关来源单元和 Raw 范围，不重写整篇、不替代 Terra 的完整审计；最终质量线由控制器编译出的全文双向收据保证。升级结论与触发事实必须写入 run-local evidence。
- Terra/Astra 都只写控制器指定的 run-local 语义复核报告；修订由 Luna max 按证据执行，修订者不能把自己的修订视为复核通过。每份 Raw 从 Terra full r1 开始，最多两次 Luna 定点返修与 Terra targeted 复验；任一 targeted 出现合格语义争议时，可对同一 request 分配一次 Astra escalation。Astra 后不再复核，明确缺陷也不能借升级增加返修轮次。报告合同错误在尚未 complete 的原槽位内修正，不另起 Agent 或语义轮次。

## 调用与交接

明确的小修允许 Terra 在 finding 中给出 `replacement_text`，由 `apply-review-repairs` 按单一、不重叠的 `raw_ranges` 机械应用；需要新增来源、调整媒体边界、重组论证或大段改写时仍交 Luna writer。

1. 主会话根据实际宿主上下文确认适用条件与配置可用性。指定模型、强度不可用，子 agent 配额耗尽或调用失败时，停止依赖写作并报告，不静默换成主模型或其他配置；可继续独立准备工作。
2. 启动任何子 agent 前先 `reserve-agent-session`，随后使用宿主的子 agent 接口按角色显式传模型、推理强度和无主会话历史 fork；启动后立即 `bind-agent-session`。写作/返修为 `gpt-5.6-luna + max`，默认 Raw 语义复核为 `gpt-5.6-terra + high`，只有控制器分配 escalation 槽位才使用 `gpt-6-astra + low`。结束时优先调用 `close-agent-session`；遗漏时必须在 Stage3 Seal 由 `sync-agent-sessions` 从已完成宿主日志自动结算，未完成或未绑定会话会阻断维护。不要把完整主对话或旧工具输出复制进提示。
3. 指定输入路径、允许修改的正文文件、验收要求及失败清单。Raw 写作者必须全文读取剪藏、完整 manifest、现行 Raw 标准和写作说明，以及强制文风样本 `raw-sources/从0到1创造开放世界设计流程-天美江岸栖-20260705.md`；该样本不是可选建议，context 生成器须提供其实际路径与哈希，子 agent 无法读取时停止写作并报告。样本只用于学习自然段的解释密度、推理展开、步骤/列表/表格的语义使用和删繁后的连贯表达，不复制其事实、结论、旧批注或固定结构，也不把每篇 Raw 强行写成流程文。语义复核子 agent 读取冻结 Clipping、manifest、Raw、Raw 标准和审核合同；Wiki 写作者读取已审核 Raw、已通过的增量规划、目标 Wiki 全文及 Wiki 规则。摘要不代替全文：保留核心语义、推理、必要例子与数值，去除闲谈冗余，不嵌入图片。
4. 每个目标文件同时只有一个写入 owner。主会话生成有界任务包，只含目标文件、冻结输入哈希、允许写入范围、必要规则和验收清单，不复制完整会话；六篇常规批次默认只有 1 个 `content_writer`（Stage1/Stage3 复用）和 1 个 Terra 主复核者。只有已经证实存在文件 owner 冲突、上下文容量不足或单会话失败时才拆分 writer，并记录原因；不得为并行而默认拆分。`execution_control.child_session_cap=12` 按实际启动会话计数，失败、中断和替换也占名额。写作子 agent 只改授权正文；语义复核子 agent 只写指定 report，不改正文、状态、审核证据、台账，不提交 Git。
5. 主会话检查实际 diff，运行既有检查器并组织必要审核；正文返修仍交 Luna max 写作子 agent，但必须以外部复核 finding 为输入，不能由修订者自判通过。回测只读与评分留在主会话，回测要求正文重写时同样走此路由。检查通过不等于用户验收。
6. Raw 复核必须先经 `prepare-raw-review` 取得模型、请求、脚本生成的报告骨架与报告路径；写完先用 `preflight-raw-review` 一次返回全部可识别机械错误和媒体边界 advisory。advisory 返回原 Terra 会话做一次明确判定，不新建 agent、不计语义复核轮次；只有必要媒体确实未转录时保留 `media_limited`。之后经 `complete-raw-review -AgentId <实际ID>` 生成机械证据，passed 后才可 `record-content-audit`。Stage1/Stage3 正文 writer 全部回收后调用 `record-writer-stage` 绑定实际 Agent ID 和最终输出哈希，随后才可封存对应包。宿主不返回实际模型身份时注明已请求但身份未独立确认，不能伪造调用或审核证明。

新规则用于后续写作，不追溯改写已封存审核包、历史调用记录或通过状态。仅变更路由不自动触发整批重写。

## 写入边界复核

派发前由主会话记录允许修改的精确文件、现有 dirty 和受保护输入哈希；回收时对照实际 diff、未跟踪文件和输入哈希，不能只相信子 agent 的完成声明。审阅子 agent 只返回或写 `prepare-raw-review` 指定的 report，不得创建或修改 host/provenance/request/receipt、其他审核者报告、控制器状态或 Git；host/provenance/receipt 由 `complete-raw-review` 根据真实调用元数据确定性生成。报告有合同错误时返回原审核者修正同一 pending report，不能由主会话改判词、改身份或补哈希冒充原审核结果。

主会话运行检查器前核对输出参数，只允许明确的本批证据路径，不能指向正文、规则、状态或已有封存证据；检查后核对受保护文件未变。脚本名包含 check/validate 不等于无写入。失败保留原件、改用新版本路径，禁止删除旧证据后在原路径重建以绕过防覆盖。发现越界时停止依赖该输出的推进，保留现场并报告；不自动恢复覆盖用户数据，也不自动修改已批准状态。

以上是执行协议与人工调度检查，不是操作系统权限隔离；共享工作目录的子 agent 仍具有宿主授予的工具能力。需要硬隔离时应另行实现只读输入与独立输出目录的运行边界。
