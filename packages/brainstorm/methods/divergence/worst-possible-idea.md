# Worst Possible Idea

## Contract

- Method ID: `worst-possible-idea`
- Category: `divergence`
- Status: `ready`
- Content version: `2`

公共约束见[方法操作约定](../OPERATING_GUIDE.md)。

## Purpose

用明确荒谬的解法暴露隐藏需求，再提取可用关系；不同于从真实失败原因反推。

## Input contract

已知问题及能标为非推荐的虚构极端。

## Use when

发散保守，可能有被“太怪”遮住的关系。

## Avoid when

需要可靠执行方案；极端会被当真；实际是事实缺口。

## Procedure

1. 标“极端只作刺激”，不用口令进入/退出模式。
2. 提出少量极端并说明坏在哪，不追求无界荒谬。
3. 拆失败关系和有价值成分，尝试缩放、限范围或改前提。
4. 落成正常场景，检查是否保留坏后果。
5. 极端作材料，正向Idea标来源；冲突标注不删历史。

## Output contract

极端→失败关系→保留成分→正向候选；极端不能直接当推荐。

## Exit conditions

有新方向或无增量即停，不必加工每个噪声。

## Single-user + AI adaptation

Agent自主提取检查；用户可否定刺激方式，不推成性格判断。

## Traceability

保留极端引用与提取路径，不把AI极端标user。

## Sources

- `SRC-WPI-001`

详情见[来源注册表](../../docs/research/public-sources.md)。

## Evidence boundary

实践来源支持极端/提取身份，降低焦虑是待检验机制，不保证激发。

`ready` 表示可执行资格，不表示实际效果已验证。以下均为合成行为示例，不是真实反馈或独立对照结果。

## Behavior cases

### Positive case

`CASE-WPI-P01`：午间分享没人听；极端“每人讲一小时，其他人不能走”坏在强占注意力，有用成分是人人有表达位置。限范围为“每人带件实物只讲最意外发现，感兴趣者饭后继续”。旅程从强制长演讲变可选短刺激，不承诺参与率提高。

### Negative case

`CASE-WPI-N01`：将“每操作收费”直接改“高价值操作收费”，未检查免费目标。先拆失败关系，冲突变体保留，寻找与收费无关的注意力设计。
