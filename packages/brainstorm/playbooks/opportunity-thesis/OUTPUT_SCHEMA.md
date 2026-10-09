# Opportunity Thesis · Output Schema

持久输出为 session `research-notes` artifact。元数据包含 Opportunity schema=2、Playbook ID=opportunity-thesis、Session ID、Source IDs、Status、Current default action、Semantic review=required。使用 [模板](../../templates/opportunity-thesis.md)。

## Sections

- Decision Object：候选、期限、默认行动、资源上限、决策者及来源。
- Opportunity Claim：用户/情境、问题/任务、切入口及来源。
- User Situation：Trigger and current behavior / Friction in a concrete episode / Proposed change and observable result / Source / status。至少一个可想象片段，合成或假设明确标注。
- D/N/S/C Evidence：透镜、支持、反证/未知、行动含义、来源；不适用说明原因。
- Strongest Alternative：替代方案、为何更好、区分信号、来源。
- Disconfirmation and Stop：风险主张、改变行动的信号、停止条件、触发后的默认行动。
- Minimum Validation：对象、观察信号、资源上限、结果→行动、owner。
- Decision and Handoff：draft / accepted / return-to-brainstorm、真实 DEC（accepted 为 user/joint）、下一动作及下游意图。

事实引用 RAW、IDEA、Evidence 或外部确切来源；推测标 assumption/unknown。accepted 仅接受下一行动，不代表立项、市场验证或启动下游。

机器目录检查验证身份、方法和模板；实例使用 scripts/validate-playbook.ps1 -SessionPath <session> -SessionRoot <root> -ArtifactPath <registered-card>。它验证 schema 2、注册 research-notes、表格/具体情境非空、来源标记与既有 ID、反证/验证上限字段及 accepted 的 user/joint DEC。所有表格必填行可标明有理由的 unknown/assumption，不用空白冒充结论。

机器不能判断具体程度、因果、来源可靠性、上限是否合理、DEC 正文是否真正接受此行动；输出 semantic_review=required，仍需按收敛合同作语义审核。
