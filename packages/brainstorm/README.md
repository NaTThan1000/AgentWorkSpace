# Brainstorm

Brainstorm 帮助人与 Agent 共同探索、形成想法并选择概念。默认边展示具体、有实质差异的点子，边根据用户反应继续碰撞；方法选择、整理和查证由 Agent 处理，重要取舍仍由用户决定。

## 现在怎样开始

直接说“开始脑暴”“帮我展开这个方向”“这些没感觉，换个角度”或“比较这几个方案”。[AI_INDEX](AI_INDEX.md) 按意图最小加载，[主协议](BRAINSTORM_PROTOCOL.md) 定义运行行为，[命令说明](COMMAND_MANUAL.md) 提供示例，无须记口令。

新建持久会话使用 [new-session](scripts/new-session.ps1)，默认 cocreate。继续已有会话使用 [resume-session](scripts/resume-session.ps1)，先读取当前进度和暂停边界。保存优先使用用户指定路径，其次宿主目录，最后 workspace/sessions；用户要求不落盘时保持纯对话。

候选以具体情境、行动／选择、结果和差异呈现。“看懂但没兴趣”会改变发散方向，“只喜欢一个部分”会围绕该部分变形，不等于接受整包。没有合适方向可以开放或暂停；不为了完成流程制造赢家。

## 方法与多源

[方法路由](methods/METHOD_ROUTER.md) 按卡点选择认知操作。当前 15 ready、4 placeholder、1 rejected 的身份以 [catalog](methods/catalog.json) 为准；ready 表示可执行资格，不能证明普遍有效。方法来源、Agent 适配和实际收益分别判断。

[Perspective](perspectives/README.md) 按遗漏选择，不要求全部执行。更多角色、标题或轮数不等于发散更好。

按具体缺口使用 [Knowledge](adapters/knowledge-context-brief/README.md)、联网研究和 [GAD](adapters/game-analysis-decision/README.md)。Agent 复用已知上下文，区分来源、假设和未知；GAD 原报告经核验直接消费，不二次写同义简报。仅准备请求不能宣称实际查询／分析完成。

## 收敛、交付与学习

[Game Concept](playbooks/game-concept/README.md) 比较能共存的完整方向和取舍，不固定包数或槽位；[Opportunity Thesis](playbooks/opportunity-thesis/README.md) 从具体用户问题形成可反驳主张。原始想法、修订链、证据、正式决定和范围排除可追溯。

[F2S v2 交接](adapters/f2s-handoff/README.md) 复用已选体验、闭环与范围，并列出缺口与下一责任。概念接受、handoff ready、原型启动和真实玩法认可分别记录；Brainstorm 不自动启动 F2S。

[方法学习](docs/method-learning.md) 随真实任务发现具体改进，验证后限定采用并维护方法／案例，反例使其收窄或撤回。产品反馈仍连接原 DEC 与真实 F2S 证据，不自动成为 Knowledge 记录。没有增量不创建记录，不新增定时维护或长期个人画像。

## 记录与权限

所有脑暴默认随讨论及时落盘，不等用户认可或会话收尾；灵感、候选、反例、修正与未决项都保留来源和演变。明确同意时当轮记录准确范围再继续；保存不等于采用或 Git 提交。执行时机与不落盘例外见[主协议第6节](BRAINSTORM_PROTOCOL.md#6-状态记录与恢复)。

新建及迁移后的活跃会话只使用新版运行合同。closed 历史档案保留原件只读，不保留旧流程继续入口。原始输入不静默丢失；Idea 正文修订追加新 ID，来源不混写。聚焦／暂存不等于正式淘汰，pruning_authority 默认 confirm，只有当前 session／目标明确授权才 delegated。

工具只证明结构与运行行为。创意价值、是否激发真人、真实玩法及广泛方法收益都需要相应证据。

| 目的 | 入口 |
|---|---|
| 运行与权限 | [主协议](BRAINSTORM_PROTOCOL.md) / [AGENTS](AGENTS.md) |
| 操作与恢复 | [scripts](scripts/README.md) / [session 合同](docs/contracts/session-contract.md) |
| 方法、来源与学习 | [methods](methods/README.md) / [来源](docs/research/public-sources.md) / [学习](docs/method-learning.md) |
| 外部交接 | [adapters](adapters/README.md) |
| 维护与验证 | [维护入口](docs/maintenance/README.md) / [tests](tests/README.md) |
| 当前状态 | [NOW](NOW.md) |


独立包不携带私人记录；公开来源只含书目元数据。外部 Knowledge、GAD、F2S 需宿主另行提供；缺失不影响独立脑暴，不得宣称已执行外部流程。
