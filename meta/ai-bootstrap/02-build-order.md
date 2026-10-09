# 唯一完整版搭建顺序

发布仓与用户工作区使用不同目录。先执行 `python scripts/workspace.py init --target <目录> --packages brainstorm f2s knowledge` 生成只读计划；按用户实际需要指定包，不要求全选。

检查冲突与运行工具后加 `--apply`。工具安装完整 meta，接入包到 modules，记录框架基线并保留事务恢复材料。没有业务包也能搭建完整根。已有框架配置不静默替换，不移动已有个人项目。

运行 `status --target <目录>`，按 AI_INDEX 读取真实入口。Brainstorm 按任务创建会话；F2S 在独立项目目录创建工程；Knowledge 空库可查，首次 Ingest 按真实目的配置范围。所有项目状态、决定和用户数据留目标工作区。

最后交付路径、可用入口、工具缺口和恢复方法，不宣称未做的行为或真人验收。后续接包用 add，升级用 upgrade；详见 [更新](04-update-flow.md)。
