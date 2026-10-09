# IMA 知识库集成指南

> 脱敏的可选集成说明。本文只管连接、选择知识库和获取来源；内容评分与入库仍由 `../protocols/INGEST_PROTOCOL.md` 管理。

## 一、启用条件

读取 `ima-config.local.json`：

- `enabled: false`：停止 IMA 路径，按普通来源处理。
- `pending_auth`：需要完成鉴权和知识库选择。
- `configured_unverified`：已有绑定信息，但必须重新获取列表并只读验证。
- `verified`：可以按本文获取来源；会话鉴权仍可能需要刷新。

配置只保存知识库 ID、名称和验证时间，不保存任何密钥。

## 二、连接器调用链

```text
1. connect_cloud_service()
2. get_knowledge_base_list(type: "KBT_MINE_KB")
3. 让用户从实时列表选择知识库
4. search_knowledge(knowledge_base_id: "<selected-id>", query: "<query>")
5. fetch_media_content(media_id: "<result-id>")
6. 将完整内容交给正常 Ingest 评分闸门
```

规则：

- 不硬编码知识库 ID；每次首次连接都以实时列表为准。
- 只传工具 schema 声明的参数，不猜 `limit` 等扩展字段。
- 搜索结果只用于定位来源，不等于授权写入。
- 初始化验证只做一次最小只读查询，不批量拉取内容。

## 三、无连接器时

可以使用 IMA 官方 OpenAPI，但凭据必须来自进程环境或系统密钥存储，例如 `IMA_CLIENT_ID` 与 `IMA_API_KEY`；不得写入仓库、命令历史或本地配置 JSON。

请求体在调用代码内部构造并用 UTF-8 发送，避免经多层命令行转义传递中文 JSON。Header 名称和 API 路径必须以当前官方接口或已安装连接器 schema 为准，不沿用本文之外的历史猜测。

连接器与 OpenAPI 都不可用时，将状态保留为 `pending_auth` 或 `configured_unverified`，列出恢复步骤，不伪造成功。

## 四、验证与状态更新

只有以下条件全部成立才写 `verified`：

1. 鉴权成功。
2. 实时知识库列表包含绑定 ID。
3. ID 与显示名称匹配。
4. 一次只读搜索成功返回合法响应。

随后更新 `last_verified_at`。鉴权失败、ID 消失或名称不匹配时降级状态并要求用户重新选择。

## 五、故障检查

| 症状 | 检查 |
|---|---|
| 无权限 | 是否先鉴权；凭据是否只在当前安全环境可用 |
| 列表为空 | `type` 是否按连接器 schema 提供；账号是否有可访问知识库 |
| 参数被拒绝 | 是否传入未声明字段 |
| 搜索有结果但取文失败 | `media_id` 是否来自当前搜索响应 |
| 中文请求异常 | JSON 是否在程序内部构造并以 UTF-8 发送 |
