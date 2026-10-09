# 构建内表现校准

当前协议：[表现与反馈 v2](../../protocols/presentation.md)。默认由 Agent 在实际可玩构建内选定方向、实现关键反馈、复核状态与时序，达到 V1 后交用户集中试玩。用户主动给定的约束持续有效，实质分歧才提前请求具体决策。

运行 `scripts/new-presentation-calibration.ps1 -ProjectPath <项目目录> -PrototypeId <ID>` 预览；加 `-Apply` 创建一份 `presentation/calibration.md`。模板是[构建内校准记录](../../templates/presentation-calibration.md)，也可合并进底稿。脚本拒绝覆盖已有记录，以及静默混入旧校准项目；不创建“批准”目录或自动生成三套候选图。

保留旧流程解决过的问题：状态语义可辨、布局与组件继承、过程与结果一致、迁入范围可追踪、关键反馈不被遗漏。证据按实际风险选择，不强制静态首屏人工测试或固定独立 Agent 团队。

本目录的 00～05 文档属于 v1 历史展开格式，新入口不加载、不由初始化器生成。已有项目记录和批准历史保留；若某新项目复杂到需要多屏／状态／衔接表，按真实问题选择展开并遵守 v2 自主边界，不能恢复逐步人工签字的默认链。

[验收证据试验附页](../../templates/acceptance-evidence-requirements.experimental.md)仍仅供实际需要时参考，不自动生成，也不回填冻结 Demo。默认证据职责已由[质量协议](../../protocols/quality-and-evidence.md)和项目索引承担。
