# 交互策划 · 专业配置

版本：2 · 2026-09-08 · role：UX

## 何时使用

状态暴露、输入、反馈、独立学习和失败恢复。当前Agent按问题加载，不要求先扮演角色或启动独立Agent。没有此类缺口就跳过；既有事实足够时不强制查Knowledge。

## 判断与选法

以玩家任务为单位看首次可得信息、可执行输入、响应和恢复。区分读懂说明、提示跟随、独立应用与迁移。发现完成率变化先查难度、提示、设备、任务版本及样本，再判断学习原因。

按需方法：[experience-hypothesis-chain](../methods/experience-hypothesis-chain.method.md)、[challenge-rhythm-theme-plan](../methods/challenge-rhythm-theme-plan.method.md)。重复问题的组合路径为 `PRO-UX-001-state-input-feedback-recovery-audit`、`PRO-UX-002-learning-evidence-guidance-fadeout`、`PRO-UX-003-decision-hold-evidence-reentry`，由当前能力目录解析新版内容与使用资格，不因旧validating／ready继承质量。

## 展开使用与误用

合成例：玩家在箭头提示下都点对按钮，只说明可跟随。下一次去掉箭头仍能解释并完成，才为独立应用提供证据；换布局检验迁移。无提示失败也可能由按钮隐藏或输入冲突引起，不能直接加更长教程。操作已认可的无障碍辅助不应为测试学习而全部撤去。

## 输出与边界

普通交互修正自主处理；需要真实体验时准备具体任务与观察问题。缺证据不停止所有分析，也不让Agent代替真实玩家填结果。 只交付影响本轮判断的结论、依据、未知和下一动作，不强制角色报告或装配收据。正式决定由宿主记录，专业意见不拥有human gate。

## 来源与自我校正

知识线索：`knowledge:domain:交互策划`，通过Provider读取并核对条件。来源可以来自项目、Knowledge、外部原始材料或可复现计算；专家自身可能错误，重要结论检查相反解释。相同模型换角色得到共识不是独立证据。

本例为合成教学说明，不是实际效果。若真实事实反驳观察或选法，按[学习协议](../../protocols/learning.md)修订正确层级并收窄／撤回；不以“更严格遵守专家提示”代替查错。[材料边界](../../protocols/knowledge-boundary.md)禁止反向改写只读Knowledge材料。
