# Forced Connections

## Contract

- Method ID: `forced-connections`
- Category: `divergence`
- Status: `ready`
- Content version: `2`

公共约束见[方法操作约定](../OPERATING_GUIDE.md)。

## Purpose

引入不顺手刺激，寻找惯性之外的关系；不为现成答案倒找“随机来源”。

## Input contract

有边界挑战、预先说明的刺激选择方式和实际刺激。

## Use when

候选沿熟悉路径；基线内变形仍同质。

## Avoid when

当前需事实核实而非找可能性；刺激改变用户硬边界。

## Procedure

1. 写要打破的惯性，再选刺激：用户给定、固定列表取项或工具实际抽样。
2. 保留选择过程，模型随口选词标Agent选择，不称真随机。
3. 拆属性/动作/关系，挑能产生桥接的部分。
4. 写刺激特征→目标关系变化→行动与后果，不靠名字相似。
5. 无有效桥接则记无增量并换方式/停止；更换刺激保留前次失败。

## Output contract

刺激、规则、桥接链、候选和未知；刺激事实与虚构演绎分开。

## Exit conditions

新关系足够或试探重复即停，不强制每属性生成候选。

## Single-user + AI adaptation

Agent自主操作，用户回应片段；使用刺激不授权外发或额外成本。

## Traceability

Run保留刺激与桥接；不把外部启发改标独立原创。

## Sources

- `SRC-FC-001`
- `SRC-FC-002`

详情见[来源注册表](../../docs/research/public-sources.md)。

## Evidence boundary

来源确认外部刺激与关联的实践身份，不宣称随机必然优于目的检索。

`ready` 表示可执行资格，不表示实际效果已验证。以下均为合成行为示例，不是真实反馈或独立对照结果。

## Behavior cases

### Positive case

`CASE-FC-P01`：挑战“共享工具忘归还”，预先取办公列表第3项“书签”。属性“暂标位置以便继续”桥接为“借走工具留下带归还时间的占位牌”。同事找钳子能直接看谁借何时回。另一桥接为归还后对照摆放图，区别在借用中可见性与归还确认。

### Negative case

`CASE-FC-N01`：先想到聊天群，再说随机词恰为“社区”。刺激不可追溯且属性无桥接；保留聊天群为独立想法，不伪造方法来源。
