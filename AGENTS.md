# Working in this repo

Canonical guidelines for every agent working on Wealth. `CLAUDE.md` points here. Rules are numbered; reference them by number (§N). Product scope and decisions live in `SPECS.md` — read it first; the design source of truth is the "Wealth v1 UI" canvas (working files in `design/`).

Linear: fioris / Wealth / WEA — https://linear.app/fioris/team/WEA/all

## §1 No backwards compatibility

This software has exactly one user: its author. There are no fallbacks, shims, legacy branches, or "if the old field is missing" paths. When a new approach is better, commit to it fully: migrate the data and move on. No dead code kept "just in case". No TODOs about backwards compat.

## §2 Remove features thoroughly

Removing a feature removes its code, the helpers/types/constants only it used, its tests, its model fields (via migration), and its docs and comments. The goal is the minimum expression of the code that is actually needed right now.

## §3 A question is not an instruction

"Did we run the tests?" is answered with *no*, not by running the tests. Work starts on an explicit request or an agreed plan. Corollary: a stated goal is a decision already made — build it, don't shrink it into an optional step 2, and don't re-litigate it. When the user enumerates, the list is the spec. Lead with the answer; add only reasoning that changes the next action.

## §4 Development

```
xcodegen generate        # regenerate Wealth.xcodeproj after editing project.yml (the .xcodeproj is generated, never hand-edited, and not committed)
./scripts/build.sh       # compile for the simulator
./scripts/test.sh        # run the test suite
swiftlint --strict       # lint (config: .swiftlint.yml)
./scripts/deadcode.sh    # Periphery whole-graph dead-code scan
./scripts/gate.sh        # all of the above, in order — THE gate
```

New source files under `Sources/` and `Tests/` are picked up automatically (directory-based target); no project edit needed.

## §5 The gate

Run `./scripts/gate.sh` before declaring work finished and after logic changes — not after every four-word edit. Say what you skipped. Two conventions the gate enforces:

- **300-line file cap** (code lines). A file over it is doing more than one thing; splitting is the fix. An unavoidable exception carries a file-level `swiftlint:disable` naming the issue that will fix it, so every exception has an owner and an end.
- **Periphery** keeps the import graph honest: unused declarations are deleted, not annotated away. A genuine keep (e.g. code reached only by the runtime) states its reason in `.periphery.yml`.

Every disabled rule and every ignore entry states its reason inline. A rule that is off because it is wrong for this codebase is a decision; one that is off because it was noisy and nobody looked is rot. Say which.

## §6 Verification matches the change

| change | proof |
|---|---|
| copy, a constant, a comment | the diff |
| logic with nothing on screen | the tests, named |
| small visual change on one screen | one simulator pass + screenshot |
| new flow or several screens | simulator pass with screenshots |
| SwiftData model change | migration exercised in a test or fresh-install run |

A new commit hash alone never invalidates existing proof. Every function with logic gets unit tests (happy path, edges, failure modes); glue with no branches earns no test — the moment it grows a branch, it does.

## §7 Commits

One concern per commit; the message describes this change only — no follow-ups, no "left alone", no future work. Fix same-kind findings in the same commit; otherwise note them in `tasks.md`. Branch names, when branching: `feat|fix|chore|refactor/<short-slug>`. Commit only when the user asks.

## §8 Swift house rules

- **Layout**: `Sources/{App, Core, Models, DesignSystem, Features/<Feature>}`. `App/` holds the entry point and root navigation; `Core/` holds engines and services; `Features/` has one directory per screen/flow. Tests mirror it under `Tests/`.
- **SwiftData stays CloudKit-compatible** even while sync is off: every attribute has a default, every relationship is optional, no `.unique` constraints.
- **Real backends behind protocols** (`TranscriptionService`, `ParsingService`, `RateService`) with mock implementations in DEBUG. Every stub is greppable: `TODO(voice)`, `TODO(rates)`, `TODO(cloudkit)`.
- **Design tokens, not literals**: colors and type come from `DesignSystem/Theme.swift`, matching the design canvas. No hex literals in feature code.
- **User-facing copy never uses an em dash.** Split the sentence, or use a colon, comma, or parentheses. Code comments and test names are exempt.
- **No census comments**: a comment that states a count of anything in the repo is wrong the moment the count changes and nothing tests a comment. State the rule and the reason instead.
- Secrets (API keys) live in `Secrets.local.xcconfig`, which is gitignored. The app fails loudly when a needed key is missing; it never silently degrades.
