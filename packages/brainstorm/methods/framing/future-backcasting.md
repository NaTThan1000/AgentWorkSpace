# Future Backcasting

## Contract

- Method ID: `future-backcasting`
- Category: `framing`
- Status: `ready`
- Content version: `2`

公共约束见[方法操作约定](../OPERATING_GUIDE.md)。

## Purpose

描述期望中的可观察未来，再倒推条件与当下探索；愿景不是预测。

## Input contract

未来场景、当前状态和资源边界，未来可为工作假设。

## Use when

方向有兴趣但不知现应验证什么；动作脱离目标。

## Avoid when

未来是成功口号；用户仍自由发散；不可控外部结果被排成保证工期。

## Procedure

1. 把未来写谁在何局面完成什么、怎样见结果；日期来自输入或标假设。
2. 倒推必要条件直至可控动作，不固定2～4节点。
3. 区分必要条件、替代路径、外部假设和证据，检查循环。
4. 向前演练今日动作能否支持下一步，不能则改路径或标不可达。
5. 给动作与停止信号，不自动实验、立项或FromDemoToSpec。

## Output contract

未来场景、条件链、当下动作与未知，不保证未来发生。

## Exit conditions

有能减少关键未知的动作或确认目标需重谈即停。

## Single-user + AI adaptation

Agent画路径查证，用户无需审批每节点；目标改变和执行权限仍分别处理。

## Traceability

动作关联未来条件和证据，愿景/能力/实际执行分开。

## Sources

- `SRC-FB-001`

详情见[来源注册表](../../docs/research/public-sources.md)。

## Evidence boundary

保留Robinson期望未来倒推身份；短任务适配没有战略预测验证。

`ready` 表示可执行资格，不表示实际效果已验证。以下均为合成行为示例，不是真实反馈或独立对照结果。

## Behavior cases

### Positive case

`CASE-FB-P01`：未来“新人独立处理常见异常且知何时求助”，倒推异常入口和责任人可见，再需交班案例验证理解。当前提案是用合成异常演练交班卡；责任人未知则先查制度。演练通过不等于新人真实独立。

### Negative case

`CASE-FB-N01`：未来“三年日活五万”被直接倒排并保证达成；市场响应不是工程必然。改为可观察体验/学习目标，增长留条件愿望。
