# Disney Strategy

## Contract

- Method ID: `disney-strategy`
- Category: `synthesis`
- Status: `ready`
- Content version: `2`

公共约束见[方法操作约定](../OPERATING_GUIDE.md)。

## Purpose

分开愿景、实现与质疑，再将矛盾转成方案修改；保留三功能，不预设三专家。

## Input contract

具体想法，愿景和落地/风险混杂的卡点。

## Use when

有吸引力方向立刻被泼冷水，或只谈愿景而跳过依赖。

## Avoid when

仅查事实；审查已完成无新信息；非简报必跑前置。

## Procedure

1. Dreamer：描绘最好的一次实际体验，扩展可能；放宽硬边界须标条件。
2. Realist：拆必要能力、可验证片段与依赖，不能擅自砍用户核心。
3. Critic：针对前两者指出假设、失败信号与反例，允许建设性修正。
4. Agent综合保留/改动/冲突，可返回相关操作，不强制固定循环。
5. 展示影响选择的矛盾与建议，不让用户读三份同义角色报告。

## Output contract

愿景片段、实现关系、质疑与修订可区分；当前候选和分歧清楚。

## Exit conditions

三功能已有足够检查可提出改动/未知即停，无切角色批准。

## Single-user + AI adaptation

原作者实践有位置/体验唤起，本仓不模拟心理锚定。单Agent可顺序检查；独立Agent仅在获授权且有必要时使用，不保证批评更强或免锚定。不自动promptX、remember或专家接管。

## Traceability

Idea→愿景/路径/质疑→新修订；保留原风险与处理，真实DEC另记。

## Sources

- `SRC-DS-001`
- `SRC-DS-002`

详情见[来源注册表](../../docs/research/public-sources.md)。

## Evidence boundary

本次核对Dilts规划练习页，保留实践身份；不采用NLP有效性主张，不称Disney本人科学实验。

`ready` 表示可执行资格，不表示实际效果已验证。以下均为合成行为示例，不是真实反馈或独立对照结果。

## Behavior cases

### Positive case

`CASE-DS-P01`：愿景“红牌使房门变桥”，实现片段为一个房间两张牌且变化可见；质疑“红牌永远唯一解时只是钥匙”。Agent提出同红牌可改门或敌路线但只能一处，把质疑变取舍；未称已可玩或获认可。

### Negative case

`CASE-DS-N02`：Critic仅说注意市场定位，掩盖“所有关卡只有一个合法动作”，再三次确认切角色。恢复失败链和修订，取消程序门；独立Agent也需核验。
