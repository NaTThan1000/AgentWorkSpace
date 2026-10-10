# 按用途选模板

模板由 Agent 按问题裁剪，用户不需要填表。默认正文只写真正影响判断的内容；普通短答用 analysis-note，有复杂证据用 analysis-report，重要选择用 decision-packet，必要验证用 experiment-plan。

analysis-request、context-brief、evidence-packet 和 expert-assembly-receipt 只供实际程序交接、上下文恢复、证据复用或独立审计，不强制同时产生。一个报告正文供 v2 宿主和人共同使用，不把机器 JSON 再改写一遍。

本目录为当前 Markdown 内容辅助；v1 JSON 的实际 schema 和 examples 仍是旧机器格式权威，Markdown 不能声称通过旧 schema。生成 v2 封装见 adapters/v2/contract.schema.json 和 scripts/adapter-cli.mjs。
