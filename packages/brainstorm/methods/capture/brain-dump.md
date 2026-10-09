# Brain Dump

## Contract

- Method ID: `brain-dump`
- Category: `capture`
- Status: `ready`
- Content version: `2`

公共约束见[方法操作约定](../OPERATING_GUIDE.md)。

## Purpose

把正在涌出的材料保留下来，给后续解释留下原始依据。捕获是外化，不是让用户先填完问卷。

## Input contract

用户的片段、担忧、例子、相互矛盾的念头；已有原话可以直接复用。

## Use when

用户连续表达，整理追问会打断；或旧记录缺少原话去向。

## Avoid when

当前问题已清楚，只需提出变体或查一个事实，此时直接做必要动作。

## Procedure

1. 保留原措辞，按自然语义分段；一段含多个意思可以建立多个引用，但不替换原文。
2. 把“我猜用户意思是……”另标解释；“想轻一点”可能指操作、系统数或美术，不能代选。
3. 输入暂歇时回显覆盖与矛盾，不逐条要求确认。只有歧义改变下一必要动作才请用户解释。
4. 从清楚的片段给一个可回应的小点子或进入适合的操作，不等“捕获完成”口令。

## Output contract

原始片段及引用，必要的 uncertain 说明；不把AI概括标为user来源。

## Exit conditions

已收输入可追溯即可继续，新原话随时追加。用户要求继续表达时不抢先归组。

## Single-user + AI adaptation

Agent负责速记、查漏与分离解释；用户不承担编号。纯对话不伪造持久ID。

## Traceability

持久记录的Run引用实际RAW；后续Idea通过Run关联原话，Parent IDs只指Idea。

## Sources

- `SRC-BD-001`
- `SRC-BS-001`

详情见[来源注册表](../../docs/research/public-sources.md)。

## Evidence boundary

捕获原则不证明已降低某位用户的认知负担；具体片段与例子为本仓适配。

`ready` 表示可执行资格，不表示实际效果已验证。以下均为合成行为示例，不是真实反馈或独立对照结果。

## Behavior cases

### Positive case

`CASE-BD-P01`：用户说“不要定时催我；但希望打开就知道下一步；偶尔又想自由逛逛”。保留三段原话。Agent标注“知道下一步≠必须做每日任务”，给“入口展示上次未解的谜，不计时”的试探片段。用户若纠正为“我要的是任务明确”，追加纠正而不擦掉原话。

### Negative case

`CASE-BD-N01`：把上述材料压成“用户需要留存系统”，删掉“不催我”，再建议每日奖励。解释吞掉了冲突。恢复原文后，把催促与方向感分开探索。
