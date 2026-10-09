# Reverse Brainstorming

## Contract

- Method ID: `reverse-brainstorming`
- Category: `divergence`
- Status: `ready`
- Content version: `2`

公共约束见[方法操作约定](../OPERATING_GUIDE.md)。

## Purpose

从目标被破坏的原因找遗漏，再转成具体机制；不是列风险后结束。

## Input contract

明确结果及能解释失败的情境。

## Use when

正向重复，怀疑遗漏导致失败的行为。

## Avoid when

目标未知；仅需取舍；反向材料会被误当执行建议。

## Procedure

1. 反写失败问题，保留正向目标和边界。
2. 列具体失败链：谁做什么→什么阻断→为何失败。
3. 对原因提出正向机制，“不要失败”不算转化。
4. 查新副作用，必要时形成另一候选。
5. 保留失败链对应，事实冲突不删历史。

## Output contract

失败链、原因、机制及场景；未转化仅作分析材料。

## Exit conditions

有新因果干预或只是重复即停。

## Single-user + AI adaptation

Agent处理反向转化，原因是否真实须证据；不自动否决。

## Traceability

正向Idea链接反向材料与目标，假设原因不升事实。

## Sources

- `SRC-RB-001`

详情见[来源注册表](../../docs/research/public-sources.md)。

## Evidence boundary

保留反向/转化实践，本例原因是假设，风险概率未测。

`ready` 表示可执行资格，不表示实际效果已验证。以下均为合成行为示例，不是真实反馈或独立对照结果。

## Behavior cases

### Positive case

`CASE-RB-P01`：目标“新人值班完成交接”，反向链“入口20文档→不知哪份有效→按旧规操作”。转化是“班次卡先见本班唯一变更和版本，旧规可追溯”。若怕漏细则，再给关键变更+例外展开变体。

### Negative case

`CASE-RB-N01`：只写困惑/延迟/失败，称三条新设计。应展开一条原因与可改变关系，解释不了先找材料。
