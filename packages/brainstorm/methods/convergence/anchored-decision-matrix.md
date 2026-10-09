# Anchored Decision Matrix

## Contract

- Method ID: `anchored-decision-matrix`
- Category: `convergence`
- Status: `ready`
- Content version: `2`

公共约束见[方法操作约定](../OPERATING_GUIDE.md)。

## Purpose

把比较依据和不确定性展开，让取舍可复核；标准成熟时才使用数值。

## Input contract

至少两个完整可比候选；目标、有权决策者及可解释标准。

## Use when

候选各有优势，“更好”含义反复变化；要检查权重依赖。

## Avoid when

仅一个值得继续方向；兴趣未清或事实太缺；硬约束不能由高分补偿。

## Procedure

1. 先比较体验、场景和范围，不能用完整方案对一句口号。
2. 依据已知优先级提出少量标准，权重写来源；未给取舍时用条件比较，不装成已认可权重。
3. 评分前定义可观察锚点，按证据/推断/unknown填格；兴趣只取真实反馈或保持未知。
4. 计算并检查关键权重/未知范围能否翻转，重复维度不能双重计分。
5. 输出建议及改变建议的条件；重要采用由用户决定，方法可交付开放比较。

## Output contract

候选、标准/锚点、依据、未知与敏感性；真实选择另留DEC。

## Exit conditions

明确可推荐范围或所缺信息即可停，不为结束方法制造决定。

## Single-user + AI adaptation

Agent定义工作锚点、算数查证；重大价值取舍交用户，不能生成用户兴奋度。

## Traceability

候选→标准来源→证据/推断→条件建议→真实DEC（如有）。

## Sources

- `SRC-DM-001`
- `SRC-DM-002`
- `SRC-DR-001`

详情见[来源注册表](../../docs/research/public-sources.md)。

## Evidence boundary

NASA和矩阵实践支持解释标准与未知，不证明主观创意可客观量化；数字为合成演算。

`ready` 表示可执行资格，不表示实际效果已验证。以下均为合成行为示例，不是真实反馈或独立对照结果。

## Behavior cases

### Positive case

`CASE-ADM-P01`：合成比较A改路战斗、B信息下注：制作可控性1/3/5表示重大未知/一项关键未知/主要依赖已验证，兴趣未表达则unknown。假定题目已给兴趣反馈，A兴趣5可控性1，B均3。等权均3；兴趣权重0.7时A3.8、B3。报告排序取决于愿为兴趣承担多少风险，而非宣布A胜。

### Negative case

`CASE-ADM-N01`：将unknown计0，新颖度/独特性重复加权，再说最高分已被用户采用。撤销越权采用，恢复未知、去重标准并保留原错误。
