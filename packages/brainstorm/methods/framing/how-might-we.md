# How Might We

## Contract

- Method ID: `how-might-we`
- Category: `framing`
- Status: `ready`
- Content version: `2`

公共约束见[方法操作约定](../OPERATING_GUIDE.md)。

## Purpose

调整问题的宽窄，使探索有方向而不预埋唯一解法；改变提问必须能改变可提出的具体点子。

## Input contract

用户情境、痛点或体验愿望；硬约束与Agent解释分开。

## Use when

连续候选都没对上；问题过宽，或把某个界面/技术写进答案。

## Avoid when

用户明确要保留某机制并改局部；不借重新定框抹去已接受方向。

## Procedure

1. 从一次具体场景提取谁、想做什么、哪里受阻；证据缺失标假设。
2. 写工作问题，用更宽/更窄变体检查边界，无需输出整批HMW句子。
3. 用两个不同解法测试：都只能是同一弹窗说明太窄；无关方案也符合说明太宽。
4. 按已知目标自主采用临时框架，立即给具体刺激；改变用户目标/硬约束才交用户取舍。
5. 用户说“不对”时回链原话，修订工作框架，保留旧解释。

## Output contract

机会问题、保留的约束及允许的具体解法；正式改变目标单独记录用户决定。

## Exit conditions

框架能产生相关且不同解法即继续；事实缺口转查证，不反复修辞。

## Single-user + AI adaptation

Agent完成定框和试算解空间；用户回应体验或实质方向，不必批准每次措辞。

## Traceability

输入RAW/IDEA/EVID→框架→新刺激；保留框架如何源于反馈。

## Sources

- `SRC-HMW-001`
- `SRC-HMW-002`

详情见[来源注册表](../../docs/research/public-sources.md)。

## Evidence boundary

参考HMW开放宽窄原则；提问合理不等于用户已认可方向。

`ready` 表示可执行资格，不表示实际效果已验证。以下均为合成行为示例，不是真实反馈或独立对照结果。

## Behavior cases

### Positive case

`CASE-HMW-P01`：原话“打开排班表看不懂下一步”。过窄的“怎样加三步教程”只导向弹窗；过宽的“怎样改善工作”无法区分。改为“临时代班者首次打开时如何认出今天必须处理的一件事？”产生“按班次显示待办”与“交班人留一条语音接力”。用户说担心遗漏，下一轮保留可见待办并探索核对方式。

### Negative case

`CASE-HMW-N01`：用户已说明不要语音，却用“怎样使交接更有人情味”重新引入语音并说是定框结果。这改写了硬边界，应标冲突而不覆盖原要求。
