# 新建与兼容接入顺序

已有工作区先使用公开仓 `audit --target <目录> --needs <当前需要>`。Agent 对照能力 criteria 审阅候选模块并记录证据，列出推荐可选项和已选包的缺失依赖。已有可替代宿主能力时不要求 meta；未确认时保留未知，不凭文件名认定兼容。

兼容安装使用 `init --mode compatible --target <目录> --packages <明确选择> --profile <已审阅记录>`，先预览再应用。选装的完整 meta 放 modules/meta，包放 modules/<id>，根规则和现有内容不被覆盖。使用时读取生成的 agent-workspace-compatibility.md；自动导航与 Skill 发现需验证实际宿主接线。没有选择不创建安装记录，缺失依赖不自动增加包。后续 add/upgrade 自动沿用 mode 并复核证据。

以下是新建工作区的默认 full 模式：

发布仓与用户工作区使用不同目录。先执行 `python scripts/workspace.py init --target <目录> --packages brainstorm fromdemotospec knowledge` 生成只读计划；按用户实际需要指定包，不要求全选。

检查冲突与运行工具后加 `--apply`。工具安装完整 meta，接入包到 modules，记录框架基线并保留事务恢复材料。没有业务包也能搭建完整根。已有框架配置不静默替换，不移动已有个人项目。

运行 `status --target <目录>`，按 AI_INDEX 读取真实入口。Brainstorm 按任务创建会话；FromDemoToSpec 在独立项目目录创建工程；Knowledge 空库可查，首次 Ingest 按真实目的配置范围。所有项目状态、决定和用户数据留目标工作区。

最后交付路径、可用入口、工具缺口和恢复方法，不宣称未做的行为或真人验收。后续接包用 add，升级用 upgrade；详见 [更新](04-update-flow.md)。
