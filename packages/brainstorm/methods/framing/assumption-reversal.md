# Assumption Reversal

## Contract

- Method ID: `assumption-reversal`
- Category: `framing`
- Status: `ready`
- Content version: `2`

公共约束见[方法操作约定](../OPERATING_GUIDE.md)。

## Purpose

反转被惯例锁住的前提以改变问题结构，不反转正式决定和已核实事实。

## Input contract

已有方向和事实/约束/工作假设/习惯。

## Use when

候选依赖同一未确认前提。

## Avoid when

事实待查；用户已锁定边界不能由方法撤回。

## Procedure

1. 列影响最大的前提与来源，不逐字反义替换。
2. 选可探索假设否定、撤去或换条件，写保留目标。
3. 演绎行动后果并检查硬约束。
4. 冲突保留依据；改用户约束只作为条件提案。
5. 按新增结构展示，反馈可收回反转，不强制全前提处理。

## Output contract

前提类型、反转、候选、依赖冲突。

## Exit conditions

打开有用差异或触及锁定边界即停。

## Single-user + AI adaptation

Agent读取来源拆解，只有改约束才交用户决定。

## Traceability

候选关联原前提/来源，旧前提与新假设可追溯。

## Sources

- `SRC-AR-001`

详情见[来源注册表](../../docs/research/public-sources.md)。

## Evidence boundary

参考枚举/反转，撤去和条件化为Agent适配。

`ready` 表示可执行资格，不表示实际效果已验证。以下均为合成行为示例，不是真实反馈或独立对照结果。

## Behavior cases

### Positive case

`CASE-AR-P01`：每日登录拿情报，目标为持续探索线索；每日/登录触发是Agent假设。撤每日得到“上次观察点在再进时变化”，反登录触发得“局内派人观察换线索”。区别回访惊喜与资源分配，未作用户选择。

### Negative case

`CASE-AR-N01`：把离线可玩当习惯反成强制联网，或无依据说账号才能存进度。恢复离线边界，存储条件查证，联网仅作改变约束的提案。
