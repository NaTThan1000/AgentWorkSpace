# Session Contract · Brainstorm 新版

## 当前合同与事实所有权

活跃运行统一 session-state schema 2，session.md record schema 2。state 拥有状态、模式、权限、路径、时间及状态历史；record 拥有 Raw／Idea／Method Run／Evidence／Decision／Artifact、Open Questions、Handoff 和 Current Continuation。状态字段不复制正文。

新建和继续只读写新版；已关闭旧档案保留原件与只读索引，不通过旧校验／运行分支继续。一次性迁移及语义保全见 宿主提供的迁移审计。

## 保存与身份

用户指定 OutputRoot 优先，其次 HostProjectRoot/docs/brainstorm，最后 workspace/sessions/YYYY/MM/session-id。ID 为 bs-YYYYMMDD-HHmmss-六位小写十六进制；目录名与 session_id 一致，已有目录不覆盖。用户要求不保存文件时不创建持久 ID。

路径必须留在相应根与当前 session，artifact 来源必须引用真实存在的 ID。容量 warning 不删除。原始话语、Idea 身份、来源和修订链不能因整理而丢失。

## 模式与状态

run_mode 必需且为 cocreate／autonomous；默认 cocreate。mode 为 quick／standard／deep，仅控制投入深度。两种交互模式初始权限均 confirm，不隐含淘汰授权，不要求 auto-report。

状态：open、paused、converged、handoff-ready、closed。
迁移：open→paused；paused→open；open→converged；converged→open；converged→handoff-ready；任一未关闭状态→closed。重复设置同值幂等；closed 不再业务修改。合法迁移不是内容质量或用户认可。

显式当前 session／目标授权才 delegated。GoalChanged、撤回和关闭使其到期，保留事件历史。状态迁移、权限改变和正文修订走对应脚本，不能靠改 JSON 绕过。用户已授权的一次性迁移为独立审计动作，不是日常手改状态入口。

## 当前恢复信息

record 必须有 Current Continuation：

- Current focus：现在正在解决什么。
- Next action：符合已有进度的下一动作。
- Pause boundary：真实暂停／执行限制，无额外限制才填 none。
- Decision refs：当前继续需继承的 DEC 引用，确无决定才填 none。

resume-session 只读返回当前焦点、决定与其历史、Open Questions、Handoff 和暂停边界；不自动推进状态、产生新想法、修改决定或启动实验。历史 NAV 保持原义，当前恢复块可以根据已有事实更新；其中的 Agent 建议不能冒充用户新决定。

## 内容与修订

所有会话按[主协议第6节](../../BRAINSTORM_PROTOCOL.md#6-状态记录与恢复)执行逐轮增量捕获，不以采用为保存条件。用户表达进入 Raw；已展示的候选、例子与比较进入 Idea／Artifact 并回链，修正保留来源和前后关系；反例、暂存方向与未决项同样保留。明确认可当轮记录实际决定范围及依据，不把未认可提案写成 DEC。每轮交付前检查增量覆盖、引用及 Current Continuation；失败说明未保存范围，不伪造记录成功。此规则不改变 schema、状态迁移或发布权限。

Raw / Idea / Run / Evidence / Decision 保存在 canonical record。长内容使用 artifact 并登记 Artifact Index，不创建多份重复人读报告。method-generated Idea 需可执行 Method ID 和匹配 Method Run；跨方法变形保留来源与父子链。

Idea 正文修订新建 ID，保留 supersedes／destination；Disposition 与 Adoption 分层。正式 rejected 需要相应授权、理由和来源；locked decisions 不可由自主流程覆盖。

phase 工具可追加实际 NAV，不要求每次四行导航与人工确认。历史 auto-report 可作为既有 artifact 查阅，不能通过旧命令新建它或要求新版必须生成。

## 反馈、交接与验证

learning-feedback 连接当前 session 中真实 user／joint DEC 与明确 FromDemoToSpec 来源。import 留 SHA256 收据，不改源 FromDemoToSpec／Knowledge／DEC。collecting-evidence、review-required、accepted-for-host、rejected 都不等于 Knowledge 已接受；重要状态依据用户已有或新作决定。普通分析用 GameAnalysisDecision v2 原报告，不重写第二份审阅简报。

方法学习走 [方法学习](../method-learning.md)，不能伪装原型验证完成。

结构校验只证明字段、引用、状态和路径；恢复时仍须检查业务边界与语义。closed 档案进入历史索引，不能用 closed 标记把本应活跃的新会话跳过必要检查。

临时副本可用于迁移／恢复试验，测试事件不写真实用户会话。真实切换前核对基线哈希，防止覆盖并行 owner。源代码、活跃记录和索引必须同批可恢复。
