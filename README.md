# skills

Agent skills for [Claude Code](https://claude.com/claude-code) and compatible
harnesses. Each directory is one skill: a `SKILL.md` with YAML frontmatter,
plus any scripts, assets, or agent configs it needs.

## Layout

```text
<skill-name>/
  SKILL.md          # frontmatter (name, description) + instructions
  scripts/          # optional deterministic helpers
  assets/           # optional templates the skill installs
  agents/           # optional per-agent configuration
_shared/            # protocol documents several skills compose
```

`_shared/` is not a skill. It holds protocol documents that skills reference as
`../_shared/<FILE>.md`, so the rules live in one place instead of being restated
— and drifting — inside each caller.

| Document | Owns |
| --- | --- |
| `_shared/REVIEW-LOOP.md` | independent finding disposition, bounded finding-family classification, the approach-stop policy, and the manual review/fix/verify loop |
| `_shared/CONTRACT-CLOSURE.md` | when an accepted boundary needs a proportionate closure matrix, and what counts as closing it without expanding the work contract |

Repositories may overlay these with stronger rules of their own. An overlay adds
and explicitly overrides; it does not restate.

## Installing

Skills are discovered from a skills directory — commonly `~/.claude/skills`.
Symlink the ones you want, or the whole tree:

```bash
git clone git@github.com:the-sarge/skills.git ~/code/github.com/the-sarge/skills

# individual skills
ln -s ~/code/github.com/the-sarge/skills/planit ~/.claude/skills/planit

# or everything, including _shared
for d in ~/code/github.com/the-sarge/skills/*/; do
  ln -s "$d" ~/.claude/skills/"$(basename "$d")"
done
```

Link `_shared` too. Skills that reference `../_shared/…` resolve it relative to
their own location in the skills directory, so a missing `_shared` leaves those
links broken with no error — the referencing skill simply proceeds without the
protocol it was supposed to compose.

## The RAS family

Most skills here drive [RAS](https://github.com/the-sarge/ras), a multi-agent
review and implementation system. `ras` is the router; use it when the right
operation is not yet clear. The rest map to one RAS operation each:

| Skill | Operation |
| --- | --- |
| `ras-review` | one-shot multi-agent review of a pull request |
| `ras-verify` | re-check a prior run against an exact head |
| `ras-review-loop` | agent-judged manual review/fix/verify iteration |
| `ras-consider` | critique a local document with no PR |
| `ras-consider-resolve` | apply decisions back to that document |
| `ras-implement` | drive a work item through an isolated local builder under the shared safety policy |
| `ras-improve-architecture` | architecture review at repository HEAD |
| `ras-grill-candidate` | interrogate one architecture candidate |
| `ras-experiment` | compare context shapes, agents, or prompts |
| `ras-benchmark` | manifest-driven benchmark suites |
| `ras-inspect` | browse existing run history |
| `ras-admin` | init, config, and maintenance |

## Workflow skills

`planit` plans standalone work and drives it to merge.
`architecture-handoff` packages reviewed architecture candidates into dispatchable
programs; `implement-architecture-slice` executes one of its child slices.
`loop-review` and `loop-review-merge` run a PR through the review loop on its own.
`append-dev-journal`, `standardize-github-ci`, `omnifocus-cli`, and
`devonthink-cli` cover journaling, CI policy, and local tool access.

## Scripts

Skills invoke their own helpers as `<skill-base-dir>/scripts/<name>`, resolved at
run time. Do not hardcode an absolute path — it breaks for every other install.
