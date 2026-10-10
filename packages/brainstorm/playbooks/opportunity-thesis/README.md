# Opportunity Thesis Playbook

- Playbook ID: `opportunity-thesis`
- Domain: `game-strategy`
- Status: `ready`
- Output: `research-notes` artifact，使用 opportunity-thesis 模板。

把方向是否值得投入变为具体用户情境、可反驳主张和下一行动。适用于游戏、服务或 Agent 工作流。

## Flow

1. 明确选择、默认行动、时间和资源边界。可比较多方向，也可比较一个方向与维持现状；不凑数量。
2. 给出具体片段：什么触发、现在怎样应对、哪里受阻、候选如何改变行为、可观察结果是什么。只有标签时先具体化并让用户回应。
3. 按 [METHOD_PRESET.md](METHOD_PRESET.md) 对卡点使用方法。事实缺口及时请求 Knowledge/Web 多源核查；重要证据依赖取舍用 GameAnalysisDecision 原报告支撑，宿主保留决定。
4. D/N/S/C 检查需求行为、用户预期、替代结构与自身能力。它是遗漏检查工具，不是完整理论；不适用透镜说明原因，关键缺口可增加关注点。
5. 按 [CONVERGENCE_PROFILE.md](CONVERGENCE_PROFILE.md) 写替代、反证、验证和停止条件。缺证保持 draft；方向不对可 return-to-brainstorm。
6. 按 [OUTPUT_SCHEMA.md](OUTPUT_SCHEMA.md) 交付易读机会卡。仅实际 user/joint DEC 才 accepted；不代表事实已验证或自动授予预算、外发、发布权限。

## Boundaries

证据注明事实/假设/未知及来源，独立来源与同源转载分开。当前兴趣不推广为长期画像。内容够支持下一步即可，不要求固定一页或无上限研究。纯对话不用虚假 ID；持久运行由 session artifact 入口创建 research-notes 后填 [模板](../../templates/opportunity-thesis.md)。

目录检查证明身份、引用和模板存在；实例用 validate-playbook.ps1 的 SessionPath/SessionRoot/ArtifactPath 参数检查注册、字段、来源及接受权限，随后审核具体性、可反驳性和真实决定范围。见 [合成案例](../../examples/redesign-playbook-examples.md)。
