# v2 host handoff

Read contract.schema.json and use scripts/adapter-v2.mjs only when an actual host requires structured transfer. Ordinary analysis needs no envelope. body.path resolves within the explicitly provided artifactRoot and body.sha256 must match. Permissions never grant host writes, decisions or experiments. prepare/consume functions validate identity and byte ownership; semantic adoption remains a host task. Brainstorm/FromDemoToSpec integrations are optional, not mandatory hosts.
