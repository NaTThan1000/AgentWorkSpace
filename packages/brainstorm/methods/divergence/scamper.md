# SCAMPER

## Contract

- Method ID: `scamper`
- Category: `divergence`
- Status: `ready`
- Content version: `2`

公共约束见[方法操作约定](../OPERATING_GUIDE.md)。

## Purpose

围绕已有对象改变具体关系；七类变换是可选提示集，不是必须跑完的七站。

## Input contract

可指出原来如何运作的基线及不可破坏的体验和约束。

## Use when

喜欢一个片段但局部不对；已有设计只剩数值/换皮变化。

## Avoid when

没有基线、目标理解错，或已有足够差异可供用户回应。

## Procedure

1. 用动作链描述基线：谁做什么→系统如何变→使用者看到什么。
2. 按卡点选替代S、组合C、适配A、修改M、转用P、删除E、反转/重排R的有用操作。
3. 明确被改对象、保留部分和新后果；组合检查相互作用，删除说明功能如何补偿。
4. 把有区分度的变体展开成场景；若仅名称/强度变化，换关系或停止。
5. 反馈指向具体变化，再沿认可部分继续；聚焦展示不等于正式淘汰。

## Output contract

基线→实际变换→新行动与后果；保留父项、未知和未采用部分。

## Exit conditions

形成可响应差异或无新增机制时停止，不以全七类覆盖为退出条件。

## Single-user + AI adaptation

Agent自主选镜头，不要求用户批准切镜头；未跑镜头不是欠账。

## Traceability

Run记录实际镜头，不伪造七类覆盖；变体Parent指向基线Idea。

## Sources

- `SRC-SCAMPER-001`

详情见[来源注册表](../../docs/research/public-sources.md)。

## Evidence boundary

七类名称沿用书目与既有事实登记；选择性使用为Agent适配，未经真人效果验证。

`ready` 表示可执行资格，不表示实际效果已验证。以下均为合成行为示例，不是真实反馈或独立对照结果。

## Behavior cases

### Positive case

`CASE-SCAMPER-P01`：基线“弓手攻击最近敌人”，用户喜欢排阵但讨厌等AI选敌。用R改为“玩家先放指向标，弓手沿线射击”；用E移除锁敌，改“移动盾手露出射线后立即出手”。前者价值在预先布置，后者在位置组合；两条均写命中/被挡结果。只喜欢后者时，保留射线组合继续变遮挡方式。

### Negative case

`CASE-SCAMPER-N01`：把弓改冰弓、火弓、雷弓标S/C/A，却没有不同选择或后果。这是同一机制的题材变体，不能当三个新机制；转变目标选择或资源关系。
