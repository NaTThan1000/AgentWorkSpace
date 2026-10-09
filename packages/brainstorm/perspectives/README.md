# 按缺口使用的视角卡

Perspective帮助发现遗漏、构造另一种差异或检查候选假设；Method执行认知变换。视角卡是本仓自编提示，不是专家身份或独立证据。

身份见[catalog.json](catalog.json)：6张core、6张game-design，均保持`validating`，没有因本次改写宣称实际收益已证实。历史`no_finding_streak`仅保留旧观测字段，不再作为自动必跑、撤卡或用户审批的计数器；没有finding也可能是已有分析已覆盖。

## 怎么选择

只挑能处理当前缺口的卡；快速/标准/deep都不规定跑多少卡。Agent自主选，不请求用户批准卡名。领域内容适用时可用game-design卡，不依赖先创建playbook，也不因为有领域卡就同时跑对应core卡。

| 可见缺口 | 候选卡 |
|---|---|
| 看不到使用者具体动作与结果 | user-experience |
| 成本/依赖是否改变概念范围未知 | implementation-scope |
| 局部成立但互相作用未知 | system-effects |
| 谁承担持续付出、激励是否错位 | value-sustainability |
| 输入/理解/接入条件排除目标使用者 | accessibility-inclusion |
| 已共识但关键假设缺反例 | counterpoint-failure |
| 首次核心选择和理解反馈不清 | gd-first-run-curve |
| 不同动机被混成一种、是否需照顾未知 | gd-player-motivation |
| 资源累计或循环消耗未检查 | gd-economy-evolution |
| 候选策略被一招覆盖 | gd-degeneracy |
| 操作结果存在但玩家看不出因果 | gd-feel-feedback |
| 内容变化与制作投入关系未知 | gd-content-throughput |

任何时点有真实新缺口都可使用，包括已收敛后的新证据；已锁定决定不能因扫描自动重开。发散中仅针对影响方向的限制，不提前全盘打分。

## 怎么用、何时停

将问题落到一个候选的具体片段，指出“哪项原假设→什么风险/新可能→如何改变下一步”。有实质finding可写既有ART/perspective-review或当前比较说明，复用引用，不强制另写一份报告。无增量可直接继续，不补全覆盖表。

卡中问题是可选提示，不要求逐题回答。没有事实时标推断/unknown，不假装进行了测试；多张卡引用同材料仍是一条证据链。用户决定重要方向，Agent可提出修改而不擅自接受/淘汰。

新证据和反例按[方法维护](../methods/MAINTENANCE.md)限定调整；结构完整与一次合成示例不足以把validating改为效果已证实。卡片不能授权spawn、专家接管、remember或新增定时任务。
