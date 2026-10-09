# Game Concept · Method Preset

本预设只描述“何时引用哪个 ready method ID”和相邻 Run 如何交接，不复述方法正文。具体输入、步骤与退出条件以 [`../../methods/METHOD_ROUTER.md`](../../methods/METHOD_ROUTER.md) 和对应方法合同为准。

## Routing

| 当前缺口 | 可选 Method ID | 交接给 Playbook 的产物 |
|---|---|---|
| 输入散乱，fantasy 和机制混在一起 | `brain-dump` | 编号 Raw 与未解释歧义 |
| 概念问题偷带解法或边界模糊 | `how-might-we` | 可继续发散的机会问题 |
| 概念依赖了「玩家肯定会 X」等未声明假设 | `assumption-reversal` | 假设清单 + 反转候选，含事实/约束/假设分类 |
| 核心循环的底层逻辑全靠类比先例，无底层推演 | `first-principles` | 基础事实清单 + 从事实重推的设计候选 |
| 需要从具体体验或验证目标反推今日探索范围 | `future-backcasting` | 未来状态 + 里程碑链 + 今日可执行行动候选 |
| 已有基线玩法，需要系统变形 | `scamper` | 带父项和变换类型的候选 |
| 候选同质化、联想固着 | `forced-connections` | 刺激—属性—桥接可追踪候选 |
| 概念由多个系统维度组合 | `morphological-matrix` | 带参数配置和一致性状态的候选 |
| 正向发散重复，anti-goals / 失败路径未被检查 | `reverse-brainstorming` | 失败候选 + 每条的正向转化候选 |
| 发散停滞，极端设计方向被心理审查过滤 | `worst-possible-idea` | 最差想法 + 每条的提取候选 |
| 想法很多但主题不清 | `kj-affinity` | 主题、孤立项与覆盖缺口 |
| 需要基于锚点比较候选 | `anchored-decision-matrix` | 评分、未知项、依据和决定分离的比较 |

## Playbook lenses

以下是输出检查透镜，不是新的 method ID：

- 玩家扮演谁，以及希望获得什么情感承诺；
- 玩家反复执行哪些可观察动词；
- 行动、系统反馈、奖励/后果怎样闭成核心循环；
- 哪些设计支柱能排除不一致功能；
- 概念明确不成为什么；
- 原型、首个可玩版本、以后和明确排除分别包含什么。

若某个透镜为空，先判断它是“尚未决定”还是“需要新的认知变换”。只有后者才建立新的 Method Run。

## Run rules

1. 一次只运行一个主方法。
2. 方法切换必须记录上一 Run 的 Input IDs、Output IDs 和 Exit status。
3. 没有合适增量时允许跳过某个方法；本预设不是固定流水线。
4. 非 ready 方法不得因场景而冒充正式运行；身份以 catalog 为准。
5. Playbook 不把方法输出自动升级为 `package` 或 `prototype`；选择继续服从 session 的淘汰权限和 Decision Record。
6. 按需把构件组织为完整方向；单项分数不能替代组合级取舍，不要求固定候选或槽位数量。

## Concrete handoff

方法输出交给用户前落到情境、行动/选择、可见后果，保留差异机制与来源。只展示足以获得回应的内容，内部可先探索更多。无新信息不为覆盖方法另开 Run；局部反馈不能自动成为整包接受。
