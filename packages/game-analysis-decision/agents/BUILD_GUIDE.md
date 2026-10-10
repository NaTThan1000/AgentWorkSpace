# 按问题选择专业内容

自然语言问题直接进入[分析协议](../protocols/analysis.md)。已有材料足够时直接分析，不先打VOI分、选模式或填装配收据。来源权限和方法选择相互独立。

## 当前内容入口

[能力目录](catalogue.json)是新版32项专业内容的机器导航：专家提供观察与选法，Method提供操作，Procedure组织重复问题，context补特定视角。目录条目是候选内容，实际使用资格叠加学习状态；来源和历史验证不自动证明新版收益。

当前Agent可以同时使用少量相关配置，无须为每个角色开Agent。先明确当前分析遗漏和预期增量，再按任务语义选择id或角色；候选默认不装配，Agent 可在已有授权内显式选择，不需要制作人逐次批准。机器lookup仅帮助筛选，不证明语义适配。没有相关性不要加载全部目录。Knowledge原则经来源解析器按需取得，不能把不存在的本地domains当作来源。

运行示例（在GameAnalysisDecision根）：

```powershell
node scripts/learning-cli.mjs audit
node scripts/learning-cli.mjs lookup query.json
```

query.json可为 `{"ids":["causal-system-map"],"contextTags":["shared-resource"],"includeCandidates":true}`，或 `{"roles":["NUM"],"query":"资源","includeCandidates":true}`。上述是有具体缺口时显式选择候选的示例；省略 includeCandidates 默认只返回当前范围有效的 scoped 内容，空结果正常，继续直接分析。候选不能单独支撑重要决定；限定使用只在记录支持的scope内成立。撤回内容从实际lookup退出，未知／retired id明确拒绝。没有请求不默认加载所有资产。

## 独立分工与停止

只有真正可分离的证据、假设或反方任务可能带来增量，且授权允许时另开独立上下文。给最小材料、写范围和停止条件；不因角色存在凑团队。相同模型有相关偏差，人数不能证明质量。

缺输入只阻断依赖结论，仍可完成查证、计算、条件性建议及验证准备；缺权限停止对应动作。重要取舍与真人体验由用户决定，宿主保存正式状态。独立分工不产生额外权限。

## 旧版与历史

memory/assets的旧Procedure、INDEX、framework及旧Provider字面状态保留历史／v1兼容解释；新版Procedure正文在procedures/，同一稳定ID显式标content_version=2。旧PASS不能给新版背书，PM-002维持retired。使用旧客户端时仍按其合同校验，不能伪造新版为v1。

Group provenance仅消费Knowledge已给收据，不重实现Group算法，不由Group命中扩张角色、预算或授权；缺失就标未提供。具体学习与撤回见[学习协议](../protocols/learning.md)，不要逐次生成无消费者的试运行收据。

兼容机器收据保持 `evaluated_groups`、`selected_via_group`、`skipped_via_group` 和原覆盖信息；`group_provenance_mode: consume_only`、`group_algorithm: not_reimplemented`、`role_effect: none`。这些字段不改变 role / Team 选择、查询等级、预算或来源授权，不把v1未声明字段静默塞入Provider。
