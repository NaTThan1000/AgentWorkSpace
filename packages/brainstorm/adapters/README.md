# adapters · 外部契约映射

Adapter 只把 Brainstorm 已有事实映射到外部系统的输入契约，不复制外部路由、问答流程或执行状态机。

当前 ready adapters：

| Adapter ID | 目标 | 输出 | 外部动作 |
|---|---|---|---|
| `knowledge-context-brief` | Knowledge ContextBrief | `knowledge-context-brief.md` + session Evidence Annex | 工具准备上下文；Agent 按现行 Query 读取并回流证据 |
| `fromdemotospec-handoff` | FromDemoToSpec design-baseline v2 | `fromdemotospec-gap.json` → `fromdemotospec-handoff.md` | 只生成交接包，不启动 FromDemoToSpec |
| `game-analysis-decision` | GameAnalysisDecision `brainstorm-adapter` | v2 request / verified report body + HostDecisionReceipt / unavailable | Agent 按需执行 GameAnalysisDecision 分析并消费原报告；工具不自动执行，缺失不伪造结果或组队 |

身份、状态、外部契约版本和验证锚点以 [`catalog.json`](catalog.json) 为机器事实源。具体边界分别见 [`knowledge-context-brief/README.md`](knowledge-context-brief/README.md)、[`fromdemotospec-handoff/README.md`](fromdemotospec-handoff/README.md) 与 [`game-analysis-decision/README.md`](game-analysis-decision/README.md)。
