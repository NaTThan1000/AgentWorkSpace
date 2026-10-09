# 原型验证反馈与FromDemoToSpec方法学习

反馈候选将项目实际观察连接到已有Brainstorm session／DEC，供后续决定复核；不代表Knowledge记录。没有上游决定时，先在项目底稿／问题表记录，不强制造一个Brainstorm流程。

在项目已有授权内，Agent可主动整理试玩、规则偏差、参数变化与重复问题的本地事实，使用“记录验证反馈”命令或自然语言均可。保留预期、实际、复现、构建与证据，并区分原因假设。不能从“原型完成”自动推导出跨项目经验。

状态为draft → ready-for-import → imported，或rejected。Agent／协调者可以审核候选是否足够具体，ready-for-import只表示适合交接，不表示支持／推翻上游产品决定，也不自动写入任何外部仓。

“导入 Brainstorm 反馈”在已有对应授权成立时由Brainstorm实际导入并追加哈希收据；FromDemoToSpec不静默回写。导入后需要分析时，由实际宿主按授权预算自主使用GAD，正式产品决定仍由用户采用。只有另有Knowledge入库授权与其流程，才能进入知识库；本流程不会自动写入Knowledge。

## FromDemoToSpec里程碑学习复盘

首次集中试玩反馈、核心玩法认可／否定、方向停止或路径接收等真实里程碑完成后，Agent自动检查一次FromDemoToSpec自身执行方法。它不替代项目反馈，也不在每个小版本运行。复盘按owner分流：

- 一次性玩法、数值和实现问题留在项目底稿、反馈或测试。
- 对FromDemoToSpec方法的确定性事实纠错可直接修正到窄边界；新的执行策略先记为`trial`，保存在`docs/learning-reviews/`，不得从一个项目宣称普遍有效。
- 制作人的协作／元认知信号交宿主复盘候选，等待明确采用；不由FromDemoToSpec直接修改Profile或全局记忆。
- 对上游产品决定的验证仍走本页原有`f2s-validation-feedback-v1`候选；不把方法学习伪装成Brainstorm产品反馈。

有增量的FromDemoToSpec方法记录至少写明：来源和具体失败、改变的操作、适用／失效边界、当前disposition、工程验证、效果尚未证明的部分及`review_when`。状态沿Review生命周期使用`candidate → trial → active → automated / retired`；结构或测试通过只支持接线完成，不能把`trial`自动升级为`active`。反例出现时引用原记录并收窄或撤回实际运行入口。

若没有可迁移增量，在当前项目验证／交付记录中写一行`no_increment`即可，证明已检查而不新增空文档。里程碑复盘不扩张权限，不修改用户目标、正式决定、质量标准，不自动导入Brainstorm／Knowledge，也不创建定时任务。

## 支持介入与学习归属核对
里程碑复盘同时检查：关键假设是否只凭单一经验，Knowledge/GAD是否在需要时实际消费，反例是否触发解释修订，是否引入无价值调用。按[共同信号](https://github.com/ZhongTyler/AgentWorkSpace/blob/main/meta/workspace/collaboration/support-and-learning.md)分流；FromDemoToSpec流程改进归本仓，GAD方法缺陷才转其learning，项目缺陷仍归项目。保留原no_increment与权限边界，不另建第二次复盘。
## 工具与字段兼容

使用[scripts](scripts/README.md)创建及验证agent-learning-feedback.md。新项目可显式传ProjectPath；DemoRoot保留历史兼容。工具不覆盖已有候选，不因目录变化改写上游决定。f2s-validation-feedback-v1的字段继续兼容现有Brainstorm导入器。

机器结构检查不证明事实正确、产品决定成立或经验可迁移。准备跨仓动作时给出具体文件、来源与目的；普通本地记录不新增人工批准链。
