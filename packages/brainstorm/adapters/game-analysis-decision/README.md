# Brainstorm → GameAnalysisDecision

GameAnalysisDecision 负责分析和 proposed 结果；Brainstorm 拥有 Raw / Idea / Evidence / DEC、session 状态和正式采用事实。脑暴方法、锁定决定与用户采用门不变。需要跨域判断、冲突查证或重要取舍时按需请求，不默认组建专家团队。

## 当前 v2 请求与消费

[request-v2.json](../../examples/game-analysis-decision/request-v2.json) 为合成输入。显式 `schema_version: 2` 使用 GameAnalysisDecision 当前最小合同；输入只引用已核实的当前 session 来源，锁定决定写入 constraints 并保留稳定引用。调用前仍按 session 合同核验实际 ID 和内容。

```powershell
node scripts/brainstorm-analysis-adapter.mjs prepare-request --input examples/game-analysis-decision/request-v2.json
node scripts/brainstorm-analysis-adapter.mjs consume-delivery --input delivery.json --consumer consumer.json
```

consumer.json 提供 `hostType: "brainstorm"`、当前 `hostRef`、报告所在绝对 `artifactRoot`，必要时提供经宿主核实的 `authorizedRefs`。写入目标必须留在同一 session。CLI 只打印请求或已核验正文，不写 session，不启动外部系统。

[GameAnalysisDecision binding](../../scripts/game-analysis-decision-v2-binding.mjs) 直接调用相邻 GameAnalysisDecision 的 v2 校验与正文消费。缺失时明确 unavailable，继续普通脑暴，不回退 Knowledge 专家或 Team。实际分析尚未运行时不声称已有结果。

## 普通分析与真正的人工门

普通 AnalysisReport 直接展示并由 Agent 消费，原文 SHA256 绑定保留；不要求再生成一份制作人审阅简报。查证建议在既有授权内由宿主继续，已授权验证必须核对授权引用。action_class 只是声明，宿主要读正文检查是否夹带重要取舍或扩大权限。

重要产品决定、Brainstorm 正式采用／淘汰、学习反馈中原本需用户决定的状态迁移仍由 user / joint DEC 拥有。GameAnalysisDecision 的同一份正文应使用户容易比较推荐、依据、代价、替代选择和未知；无需为 human_review 重写第二份报告。

反馈回流时，GameAnalysisDecision 原报告可作为已有 draft-analysis Artifact 的正文或链接来源，按 session 合同登记；不在机器 JSON 后另建一套同义说明。普通分析可提供建议，但不能自动更新需要人工决定的 learning-feedback 状态。用户决定先写宿主 DEC，再调用原 `prepare-host-decision` 生成只读回执。无真实确认不能填 producer_confirmed 或 host_record_confirmed。

## 正式回执与历史证据

新请求和正文消费统一使用 v2，旧请求格式和接管别名已退出运行入口。已发出的历史 session 报告、请求和哈希保留原件，仅用于追溯。

`prepare-host-decision` 使用 GameAnalysisDecision 当前仍在消费的 HostDecisionReceipt v1，它记录宿主已经发生的真实 user / joint 决定，并非旧脑暴流程兼容分支。无真实确认不得生成正式接受事实。Knowledge 查询、FromDemoToSpec 启动和实验执行都必须有各自的实际执行证据。
