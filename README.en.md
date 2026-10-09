# AgentWorkSpace

[简体中文](README.md) | **English**

AgentWorkSpace helps you set up a lasting workspace for an AI agent. It includes a complete set of collaboration rules and reusable methods, with Brainstorm, FromDemoToSpec and Knowledge available when you need them.

You can ask your agent:

> Set up a workspace in the directory I specify, with brainstorming, prototype development and a knowledge base. Check the environment and existing files, show the installation plan, then apply changes that have no conflicts.

There is one complete meta edition. You do not need to choose a feature combination. The agent reads rules and methods as each task requires; installing the framework does not require running every workflow on every task.

## Get started

Clone or download this repository into its own directory. Keep your working directory separate. The installer requires Python 3.10+; package scripts also require Node.js 22+ and PowerShell 7. Knowledge needs Git before its first Ingest run. Runtime verification for this release was performed on Windows; check each package's guidance for other platforms.

Run these commands from the distribution directory. Preview before applying:

```text
python scripts/workspace.py doctor
python scripts/workspace.py init --target <workspace-path> --packages brainstorm fromdemotospec knowledge
python scripts/workspace.py init --target <workspace-path> --packages brainstorm fromdemotospec knowledge --apply
python scripts/workspace.py status --target <workspace-path>
```

You can omit `--packages` or select only the packages you need. Meta is always installed. Use `add` to add packages later and `upgrade` to update them. Commands preview changes by default; `--apply` writes them. Resolve any reported `conflicts` first.

## Use the workspace

| Component | Installed location | Example task |
|---|---|---|
| [meta](meta/README.md) | Workspace root | State your goal, constraints and completion criteria |
| [Brainstorm](packages/brainstorm/README.md) | `modules/brainstorm` | “Help me explore this problem…”; create sessions as needed |
| [FromDemoToSpec](packages/fromdemotospec/README.md) | `modules/fromdemotospec` | “Build a playable prototype…”; develop it in a separate project directory |
| [Knowledge](packages/knowledge/README.md) | `modules/knowledge` | “Query the knowledge base” or “Ingest these sources”; an empty library can be queried |

Start tasks once the framework is installed; create business content when the task needs it. FromDemoToSpec provides a development workflow. The game project is created during a specific development task. Before the first Knowledge Ingest run, the agent must configure the real knowledge scope and establish a separate local Git baseline inside the module. Existing libraries keep their history. Do not use the outer repository as that baseline or create a remote or push automatically. The original setup wizard remains available for standalone customization; installation does not require another interview. Keep the registered module directory name unchanged.

Keep projects under `projects/` or a directory you choose. Sessions, knowledge content and personal configuration belong in your workspace, not in this distribution repository. `.agent-workspace/state.json` records installed versions and framework file baselines; it does not own your business records.

Meta also includes [Humanizer-zh](meta/workspace/.agents/skills/humanizer-zh/SKILL.md). Use it to edit Chinese prose for clarity while preserving facts, uncertainty and the author's voice. It is editing guidance, not an authorship detector. English documentation should preserve the same factual accuracy.

## Compatibility, upgrades and recovery

See [catalog.json](catalog.json) for the current version and component inventories. Each release names its direct predecessor and provides compatibility notes, steps and recovery instructions in `upgrades/`. Published tags are immutable. Follow the declared release chain.

```text
python scripts/workspace.py upgrade --target <workspace-path>
python scripts/workspace.py upgrade --target <workspace-path> --apply
python scripts/workspace.py rollback --target <workspace-path> --transaction <transaction-id>
python scripts/workspace.py rollback --target <workspace-path> --transaction <transaction-id> --apply
```

Upgrades compare the saved baseline, local files and incoming content. If both local and upstream versions changed a file, the tool reports a conflict. If upstream did not change it, local edits or deletions remain. User data is preserved. Each application has transaction backups, and rollback also checks for later edits.

When upgrading from 1.0.0, the `f2s` package and `modules/f2s` become `fromdemotospec` and `modules/fromdemotospec`, including user files inside that directory. Old command arguments and script entrypoints remain compatible. Existing session protocol IDs, fields and artifact names are not forcibly rewritten. See the [1.1.0 upgrade guide](upgrades/1.1.0.md). Earlier standalone released packages must first follow the [1.0.0 migration guide](upgrades/1.0.0.md), then upgrade through the release chain.

If a crash leaves `install.lock`, check its PID and the actual process. Once you confirm no installation is running, preserve the evidence, remove the lock and preview transaction recovery. Do not automatically clear another process's lock.

## Maintenance and releases

Maintain content and behavior in their source repositories, then publish directly into the owned `meta/` or `packages/<id>/` directory here. The three business sources no longer generate local released copies. Commit the source before running `scripts/publish.py --source <source-path> --apply`. Without `--apply`, the publisher only previews changes; uncommitted sources cannot be formally published.

Before releasing, check affected source contracts, package runtime behavior and upgrades from the previous version. Run `python -B -m unittest discover -s tests -v`. Write the upgrade guide, seal the inventory with `scripts/build_catalog.py --version <version> --previous <previous-version>`, then run `workspace.py verify`. Tag the verified commit and check a fresh remote clone after publication.

Use the relative links at the top to switch between this page and [简体中文](README.md). Keep both pages aligned on features, commands, versions, limitations and licenses. Package documentation is currently mainly in Chinese.

The public Knowledge package maintains an independent portable framework 2.0 implementation; it is not the private host's latest consolidated controller. This repository contains no private knowledge, sessions, profiles, runtime receipts or credentials. Humanizer-zh retains its [MIT license and source record](meta/workspace/.agents/skills/humanizer-zh/references/UPSTREAM.md). Other content keeps its existing rights; public visibility does not grant a new license. Engineering checks do not establish creative quality, real game play, user content approval or long-term results.
