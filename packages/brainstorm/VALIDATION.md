# 独立包验证
要求 Windows PowerShell 5.1 或兼容 PowerShell，以及 Node.js（支持原生 ES modules）。
在包根目录运行 powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-release-contract.ps1。
合同检查目录与来源隔离、相对链接、当前方法和接线结构，并实际新建、恢复、暂停会话，确认恢复不修改状态、采用和暂停边界。GAD 缺失路径返回 unavailable，不能据此声称完成分析。
测试只使用系统临时目录，不污染包与业务记录；结构通过仍需要 Agent 语义审查和真人效果反馈。
