# 消化可选语义子 Agent 审核规范

> 适用：现行 schema 8 标准（interactive）与自动（deferred）批次，使用同一 package-data v2。默认不装配本文件定义的整阶段独立复核；显式 precision 在相同格式启用 enforced，shadow 仅观察。历史 v5/v6 按原证据解释，不创建旧格式新批次。
>
> 当前合同：INGEST_PROTOCOL、ingest-stage-gates 与实际控制器；本文件规定 reviewer 的输入、输出和边界。原语义审核设计保留为历史设计依据。

Raw v2 的必需全文双向独立审核另由 `raw-standard-v2.md`、`raw-writing-v2.md` 与 `raw-quality.mjs` 规定，不受此处整阶段 optional 开关关闭。两类报告 schema 不可混用；独立 Raw reviewer 可按指定路径保存其 report，但不能编辑知识正文或控制器。

## 共同约束

- 审核者必须是 fresh-context 子 Agent，只读请求列出的事实文件；不得读取生产者完整对话、自评或后续阶段产物。
- 审核者不得编辑文件、运行写入脚本、执行 Git 提交/回滚或改变控制器状态。
- 只输出 schema v1 receipt。每条阻断/实质 finding 必须给出证据路径、位置与所需动作。
- `pass` 不得含 blocking/material finding；`revise` 表示当前阶段可在一次最小返修后复审；`escalate` 表示现行规则无法唯一裁决，主 Agent 必须熔断。
- 机械检查仍由既有控制器、source audit、链接/容量/维护收据承担；审核者不因格式或命令问题制造语义 finding。

## scoring

先独立判断来源身份、A/B 证据、历史覆盖和终态，再比较评分包。重点识别把个案、二手判断或未证实结论误判为通用直接消化，以及遗漏的合并/跳过边界。

## stage1

完整回读 Clipping 与 raw，以章节、定义/条件、因果链、案例和限定语为尺度。必须寻找 source manifest 与主审核可能共同遗漏的独立含义；不得仅复跑 unit 计数或样式检查。

## stage2

先提出 raw 的独立 Wiki 落点与不适用理由，再比较 Stage 2 包。检查错误归属、遗漏的第二落点、重复覆盖、批注消费不完整和被隐藏的知识结构变更风险。

## stage3

读取 Stage 2 计划、Stage 3 包与冻结 diff，检查计划是否兑现、批注是否按计划处置、增量文字能否回指 raw、限定语是否丢失。不得重做链接、计数、容量、哈希或 Git ancestry 检查。

## 依赖范围与复用

请求以已封存阶段依赖、实际候选和差异生成；不固定要求某几篇私人Wiki、最少12篇Wiki或3篇raw。候选为空要给出可复核的检索范围与原因，不把空清单当充分发现。评分和规划的旧Wiki依据保留完整版本，Stage3检查实际融合结果。哈希证明版本一致，不证明判断正确。

发现来源/规则变化或关键遗漏时，主Agent只重开受影响阶段并归档旧结果；新的请求必须重读实际改变的证据。same-context作者回读、fresh-context复核和独立匿名效果评测分别记录，不混同。任何模式均不得用一次技术pass替代用户的正式阶段或最终批准。
