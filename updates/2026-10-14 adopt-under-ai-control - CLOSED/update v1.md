# Adopt edutube under AI Control

## Goal
Bring the existing edutube codebase under the AI Control standard
(see ~/.ai-control/modules/STRUCTURE.md) without disturbing any working
code. edutube predates the standard and was already ~90% compliant — this
update adds only the missing scaffolding.

## What was done
- **Verdict:** project (not an organizer) — a single self-contained
  codebase, not a container of other projects.
- Added the `.project` marker: `modules: [STRUCTURE, CODING, WORKFLOW, UX]`,
  `secrets: none`, `claude_md_generated: 2026-10-14`.
- Created `updates/` (this folder) and `issues.txt`.
- Confirmed `.gitignore` already covers `.env`; the project has no secrets
  (oEmbed needs no API key, GitHub auth is via `gh`), so no `.env` was
  created.
- Merged the global modules into the existing `CLAUDE.md`
  preservation-first: the bespoke operating doc stays authoritative; only
  the genuinely new module guidance (updates/research-spike workflow, the
  UX-expert-agent rule) was folded in.

## Decisions
- Did **not** regenerate `CLAUDE.md` from scratch — the existing hand-written
  doc carries project-specific rules (owner authority, 3-component
  modularity, the build+report protocol) the generic modules don't capture.
- Did **not** fabricate a retroactive roadmap for the already-shipped phases;
  that history lives in INIT.md and git.

## Status
Done / CLOSED.
