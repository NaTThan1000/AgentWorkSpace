# 我的 Agent 工作区

直接告诉 Agent 你希望完成的事。完整协作框架已经就绪；Agent 自主定位资料、实施、验证和交付，重要决定和外部动作按实际授权。

AGENTS.md 定义公共边界，COMMAND_MANUAL.md 定义风险与完成条件，AI_INDEX.md 帮助定位。modules 中是已接入的业务包；项目产物放 projects 或用户指定目录，Knowledge 内容放其接入实例，不修改发布仓模板。

加入或更新包时使用 AgentWorkSpace 发布仓的 scripts/workspace.py；安装记录位于 .agent-workspace/state.json，事务恢复材料位于 .agent-workspace/transactions。保留发布仓作为安装源，用户工作区是独立目录。
