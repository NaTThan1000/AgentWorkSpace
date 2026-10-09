# Releases

## 1.2.0 — 2026-10-09

- Compatible mode audits existing workspaces and recommends optional packages from current needs.
- Missing dependencies are capabilities, satisfiable by reviewed existing providers; matching names alone are not proof.
- Only explicitly selected components are installed. Scoped complete meta lives under modules/meta; root rules remain intact.
- Mode and evidence-backed provider records persist across add/upgrade, with normal conflict, transaction and rollback protection.
- Existing full-mode installations retain their layout. See [upgrade and recovery](upgrades/1.2.0.md).

## 1.1.0 — 2026-10-09

- Humanizer-zh is included as a reusable Skill, with its MIT notice and pinned source revision.
- Chinese and English READMEs provide equivalent instructions and clickable language links.
- FromDemoToSpec is the canonical display name; `fromdemotospec` is the package ID and directory name. New script, schema, adapter and template paths use the full name.
- Upgrades from 1.0.0 relocate the installed package and user files with transactional recovery. Old arguments, entrypoints and session wire formats remain compatible.
- See [upgrade and recovery instructions](upgrades/1.1.0.md). The v1.0.0 tag is unchanged.

## 1.0.0 — 2026-10-09

- First unified distribution: one complete meta edition, with optional Brainstorm, F2S and Knowledge packages.
- One interface for preview, installation, package addition, legacy adoption, upgrades, status, environment checks and recovery.
- File ownership and baseline checks preserve user data and report conflicting framework changes before writing.
- Source repositories publish directly to their owned component. Provenance and exact inventories are recorded; source `released/` staging is retired for the three business packages.
- Knowledge retains its independently portable framework 2.0 implementation; private host controller changes require explicit adaptation before publication.
- Previous form: the three legacy source releases. See [compatibility and migration](upgrades/1.0.0.md). No earlier unified repository version is implied.

Validated with isolated runtime fixtures, actual previous-package migration and recovery contracts. These checks do not establish content acceptance, creative quality, real game play or long-term effects.
