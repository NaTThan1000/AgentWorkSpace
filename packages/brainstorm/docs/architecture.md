# Brainstorm 架构与事实归属

Brainstorm 把模糊想法变为可以碰撞、比较和继续推进的具体方向。默认 `cocreate`，Agent 展示少量实质不同的情境，吸收用户对片段的反应，按问题切换捕获、发散、综合与比较。阶段是可回转操作，不能按固定清单阻断用户。

## 运行链

`README / COMMAND_MANUAL → BRAINSTORM_PROTOCOL → 方法与领域规则 → session / 工件 → 按需外部消费`

| 能力 | 目的与权威 |
|---|---|
| Method | 一次认知变换；身份在 methods/catalog.json，操作与失效条件在对应正文，路由在 methods/METHOD_ROUTER.md |
| Perspective | 针对具体缺口换观察位置；不是必须跑完的专家角色团队 |
| Playbook | 领域问题的比较与交付语义；复用公共方法，不把游戏机制强加给非游戏问题 |
| Adapter | 核对和转换外部合同；准备请求、实际查证、消费正文、正式决定、执行分别保留证据 |
| 方法学习 | [有界学习](method-learning.md)记录触发、来源、实际内容变化、检查与适用范围；不拥有全局偏好或产品决定 |

## 一份事实由谁维护

| 事实 | 权威源 |
|---|---|
| 新建、恢复、状态及权限 | session-state.json（schema 2）；run_mode 与 pruning_mode 分开 |
| 原始输入、想法谱系、正式决定、来源 | session.md（record schema 2）；RAW / IDEA / DEC 保留原义 |
| 当前焦点、下一动作、暂停边界、决定引用 | session.md 的 Current Continuation；历史 Phase Navigator 保留过程 |
| 详细分析和学习反馈 | artifacts 与 Artifact Index；正文不能用摘要替代证据 |
| 当前会话索引 | workspace/sessions/index.json，由工具生成，不拥有第二份业务状态 |
| 来源身份与适用限制 | docs/research/public-sources.json 及专业正文；来源可靠不等于方法实际有效 |
| 正式接受、淘汰与关键取舍 | user / joint DEC 或已有明确范围的委托；运行模式不扩大权限 |
| 外部事实与执行状态 | Knowledge / GameAnalysisDecision / FromDemoToSpec 对应权威源；Brainstorm 只保存来源及消费结果 |

[session 合同](contracts/session-contract.md)规定新建与继续统一新版。已关闭记录保持历史原件并只读索引；没有旧活跃运行分支。一次性迁移证据放在本次审计目录，迁移不推进业务状态。

## 内容、质量与交付

候选要能看见具体情境、动作或选择、结果及差异。比较完整方案时说明组合机制和代价，喜欢一个构件不等于接受整包。允许尚未选择就保存或暂停；生成已选方向的 brief 必须绑定真实决定。

Knowledge 补知识与案例，Web 补当前来源，GameAnalysisDecision 分析冲突与重要取舍；按缺口引入并保留多源。不把普通分析变成一轮新人工门，也不让分析报告替用户做正式决定。外部不可用时说明缺口，不能伪造运行或自动组队。

结构正确、操作可执行、有限比较收益和真实用户共创体验分别验收。机器字段、模板完整、测试 PASS 不能证明用户已被激发。

## 存储与发布

有宿主时会话归宿主；无宿主使用本仓 private sessions。原始会话、外部报告及 private 审计材料不进入公开构建白名单。发布源只包含经检查的可复用内容和明确合成的示例；本地构建验证不等于发布或 push。
