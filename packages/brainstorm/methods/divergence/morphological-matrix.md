# Morphological Matrix

## Contract

- Method ID: `morphological-matrix`
- Category: `divergence`
- Status: `ready`
- Content version: `2`

公共约束见[方法操作约定](../OPERATING_GUIDE.md)。

## Purpose

拆分有区别的维度，抽取相容且有代表性的组合；发现线性联想遗漏的配置。

## Input contract

至少两个能改行为的参数及可区分状态；约束与未知分开。

## Use when

多个关系共同决定方案，单维微调没有新方向。

## Avoid when

参数是“好玩/趣味/体验好”重名；目标不清或穷举超预算。

## Procedure

1. 定义少量有决策意义的参数/状态，用场景说明；Agent自主拟定，无固定参数表审批。
2. 检查重叠依赖，理论组合数只说明规模，不作产出配额。
3. 标有依据的不一致状态对，unknown/unchecked不能写excluded。
4. 按差异/边界/反馈抽组合，说明未检查范围。
5. 展开完整场景，检查多项联用冲突；两两相容不保证整包相容。
6. 展示差异，用户可改参数；采用另行决定。

## Output contract

参数、抽取理由、完整配置、排除依据及unknown/unchecked和场景。

## Exit conditions

覆盖当前有用差异或无增量即停；重要歧义才询问。

## Single-user + AI adaptation

保留形态场/一致性原理，采用有限抽样而非穷举。

## Traceability

配置保留参数=状态与基线；未展示项不等于正式拒绝。

## Sources

- `SRC-MM-001`
- `SRC-MM-002`

详情见[来源注册表](../../docs/research/public-sources.md)。

## Evidence boundary

参考参数组合与交叉一致性实践；有限抽样为Agent适配，不宣称覆盖全部可行解。

`ready` 表示可执行资格，不表示实际效果已验证。以下均为合成行为示例，不是真实反馈或独立对照结果。

## Behavior cases

### Positive case

`CASE-MM-P01`：取件服务参数：位置={固定柜,流动车}、确认={一次码,熟人登记}、时间={窗口,随取}，2×2×2=8。已知车只18点停留，流动车+随取冲突。抽固定柜+一次码+随取与流动车+熟人登记+窗口：前者下班扫码，后者当面交接。隐私及无人值守成本仍未知，不能靠矩阵决定。

### Negative case

`CASE-MM-N01`：用方便/便捷/省事作三参数生成八名字后隐藏七个。应改位置/确认/时间等关系，保留原项去向。
