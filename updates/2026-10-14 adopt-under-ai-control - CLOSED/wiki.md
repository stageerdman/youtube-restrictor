# Wiki — adopting a pre-existing project under AI Control

Durable lessons from bringing edutube under the standard.

## Preserve a strong existing CLAUDE.md; don't regenerate blindly
The `adopt` routine says "generate CLAUDE.md from the global modules," but a
mature project often already has a hand-written CLAUDE.md worth more than a
fresh module compile. The governing detail is in the `rebuild-claude-md`
routine: **preserve project-specific rules added locally.** So the right move
for an existing project is a preservation-first *merge*, not a regenerate —
keep the bespoke doc authoritative and fold in only what the modules add that
isn't already there. A from-scratch regenerate is only appropriate for a
genuinely new project (the `new-project` routine).

## "secrets: none" is a valid answer — don't create an empty `.env`
STRUCTURE.md lists `.env` in the standard scaffold, but it also says keep
small projects flat. When a project genuinely has no secrets, record
`secrets: none` in `.project` and skip the file. A gitignore rule for `.env`
can stay regardless (cheap insurance).

## Don't fabricate update history
An already-shipped project has no real `updates/` trail. Create the folder and
record the adoption itself as the first update, but don't invent a retroactive
roadmap for phases that already shipped — that history already lives in the
project's own INIT/README and git log.
