# integrations · 可选集成

集成默认关闭，不属于知识库核心运行前提。

## IMA

- 指南：`IMA-GUIDE.md`
- 版本化模板：`ima-config.template.json`
- 本地运行配置：`ima-config.local.json`（被 `.gitignore` 排除）

只有本地配置 `enabled: true` 时，Ingest 才加载 IMA 指南。密钥、cookie、session token 和个人凭据路径不得进入任何知识库文件。

合法状态：`disabled`、`pending_auth`、`configured_unverified`、`verified`。未完成真实只读调用不得标记 `verified`。
