# Game Concept · Output Schema

## Identity

持久输出在当前 session；纯对话用来源说明，不伪造 ID。新建与活跃会话使用下列版本，关闭文件只作历史材料。

## Combination schema 2

元数据为 Combination schema=2、Playbook ID=game-concept、匹配 Session ID、Semantic review=required。Markdown 值使用反引号，见模板。

Package Options 固定表列：

`Package ID | Name | Experience fragment | Mechanism and coherence | Included Idea IDs | Deferred Idea IDs | Trade-off`

每包 PKG-###，至少一个既有 IDEA。Experience fragment 写情境、行动/选择、可见后果；Mechanism and coherence 写循环与构件关系；Trade-off 写得到什么、放弃什么。不同包可共享 Idea，但须有实质差异。没有包可保存探索状态。

Package Selection 表列：

`Gate status | Selected package ID | Decision IDs | Selection rationale | Deferred package IDs`

open/paused 的 selected/decision/deferred 为 `-`，rationale 写原因和继续边界。selected 引用存在 PKG、现有 user/joint DEC、理由及全部其他包 ID；单包 deferred 为 `-`。选择表明确绑定 PKG 与 user/joint DEC；既有决定可能只引用代表性 Idea，不强制所有构件逐项覆盖。引用检查不能证明自然语言真的接受整包，必须核对决定正文与所选范围，禁止用无关决定授权。

## Brief schema 3

元数据增加 Brief schema=3，Selected package ID 与已 selected 组合一致。生成仅创建 draft 骨架，空骨架不能冒充通过验证的简报。

必需章节：Concept Frame、Experience Fragment、Player Fantasy、Core Verbs、Core Loop、Design Pillars、Anti-goals、Scope、Validation and Open Questions、Decision and Handoff。

新增 Experience Fragment 表头为 `Situation | Player action / choice | Visible consequence | Source IDs`。其他表头见 [模板](../../templates/game-concept-brief.md)。每个内容表至少一行，Source IDs 为既有 RAW-* 或 IDEA-*，DEC 只放决定栏。LOOP-###、PILLAR-###、ANTI-###、CHECK-### 唯一；类型 hypothesis/risk/question/test；Scope 至少 prototype 和 excluded，可加 first-playable/later。

Brief status 为 draft/accepted/return-to-brainstorm；accepted 必须已有 user/joint 决定支持。F2S intent 仅 not-requested/requested。片段从既有候选展开；历史迁移不能推出的细节保留未知，不伪造用户认可。具体性、机制关系与表现反馈仍由语义审核判断。

## Delivery

Brief 可独立交付，请求 F2S 时复用现行 gap/handoff v2。验证器返回 brief_schema=3、selected_package_id、brief_status、f2s_intent、semantic_review=required；工程 PASS 不是用户接受或玩法效果。
