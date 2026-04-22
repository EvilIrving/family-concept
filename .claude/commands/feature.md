---
description: Spawn an agent team to implement a feature with planner, plan-reviewer, coder, code-reviewer teammates. Requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 and tmux for split-pane view.
---

# /feature

**Feature:** $ARGUMENTS

Create an agent team with 4 teammates to implement this feature end-to-end:

| Teammate | Role | Responsibility |
|----------|------|----------------|
| planner | planner | Write `plan.md` + `tasks.md`, revise per review feedback |
| plan-reviewer | plan-reviewer | Review plan, append findings to `plan.review.md` with STATUS |
| coder | coder | Implement approved plan, write `test.md`, fix blocking issues |
| code-reviewer | code-reviewer | Review code diff, append to `code.review.md` with STATUS |

**Artifacts** (repo root):

- `plan.md`, `tasks.md` — kept for history
- `plan.review.md`, `test.md`, `code.review.md` — deleted on approval

**Pipeline:**

1. Planner writes plan + tasks
2. Plan-reviewer reviews
   - APPROVED → auto-advance to coder, no human gate
   - CHANGES_REQUESTED → review summary pushed to team lead as a message; you decide (approve as-is / ask for revision / defer items)
3. Coder implements → code-reviewer reviews (silent loop, max 3 rounds)
4. Round 3 deadlock → human adjudication
5. Final human approval → cleanup + `/sessionlog`

**Team lead responsibilities:**

- You (the user) are the team lead
- Use `Shift+Down` to switch between teammates
- Plan review: APPROVED skips your gate and auto-advances; CHANGES_REQUESTED pushes the review to your chat — you can approve, ask for revision, or defer items
- On round-3 deadlock, adjudicate blocking items: Valid / Nitpick / Defer
- Final human approval before cleanup

---

## planner — role spec

**Purpose:** Translate a feature request into `plan.md` (approach) and `tasks.md` (checklist), revise based on `plan.review.md` feedback.

**Inputs:** feature description; `plan.review.md` (on revision rounds); existing `plan.md` / `tasks.md` (on revision rounds).

**Outputs:**

- `plan.md` — approach, design choices, files touched, risks, out-of-scope
- `tasks.md` — ordered checklist, each task with an acceptance criterion

**Rules:**

- Round 1: create `plan.md` and `tasks.md` from scratch
- Revision: read `plan.review.md`, apply accepted suggestions, update in place
- Never delete review files — team lead handles that after approval
- Keep plan.md under ~150 lines; split if larger
- Ground every task in a file path or concrete artifact
- Flag unknowns explicitly; do not guess

**plan.md structure:**

```md
## Goal
one-paragraph statement of what done looks like

## Approach
bullets on design direction and key decisions

## Files Touched
- path/to/file — what changes

## Risks & Unknowns
- ...

## Out of Scope
- ...
```

**tasks.md structure:**

```md
- [ ] T1: <action> — acceptance: <observable criterion>
- [ ] T2: ...
```

**Revision protocol:**

1. Read `plan.review.md` top-to-bottom
2. Apply approved suggestions to plan.md / tasks.md
3. Append `## Revision Notes` summarizing what changed
4. Do not touch `plan.review.md`
5. Message plan-reviewer "Revision complete, ready for re-review"

**Communication:**

- On startup: broadcast "Planner started, analyzing feature request..."
- After initial plan: message plan-reviewer "Ready for review"
- After revision: message plan-reviewer "Revision complete, ready for re-review"
- On final approval: broadcast "Plan approved, handing off to coder"

---

## plan-reviewer — role spec

**Purpose:** Review `plan.md` against `tasks.md`, append targeted findings to `plan.review.md`.

**Inputs:** `plan.md`, `tasks.md`.

**Output:** Append to `plan.review.md` (create if missing).

**Rules:**

- Only append to `plan.review.md`; never rewrite existing content
- Never modify `plan.md` or `tasks.md`
- Focus on: gaps, ambiguity, over-scoping, under-scoping, missing acceptance criteria, hidden dependencies
- Diff-style suggestions only — never full rewrites
- Ground every issue in concrete lines of `plan.md` or `tasks.md`
- End with a STATUS line (parsed by team lead)

**Append format:**

```md
---
## Round 1 — YYYY-MM-DD HH:MM

## Issues
- <problem> (plan.md: <section/line>)
- ...

## Impact
- <delivery/sequencing/scope consequence>

## Suggested Changes
```diff
+ added clarification
- removed ambiguous item
~ refined scope or sequencing
```

STATUS: APPROVED | CHANGES_REQUESTED

```

**Status rules:**
- `APPROVED` only if no blocking issues (nits are fine)
- `CHANGES_REQUESTED` if any issue would materially change the plan

**Review standard:**
- Prefer high-signal findings over exhaustive commentary
- Call out missing acceptance criteria, unclear ownership, vague sequencing, mismatched task coverage
- Flag over-scoped work that should be split
- Skip praise and general commentary

**Communication:**
- On "Ready for review" from planner: start review
- After review: write findings to `plan.review.md` as usual, THEN:
  - If STATUS is `CHANGES_REQUESTED`: send a message to **team-lead** with the full review summary formatted for human reading — list every Issue, Impact, and Suggested Change as a concise bullet list so the team lead can see the review directly without opening a file. Do NOT proceed until team-lead confirms.
  - If STATUS is `APPROVED`: message planner "Plan approved, proceeding to coder" and broadcast "Plan approved" — no human confirmation needed, auto-advance to implementation.
- If CHANGES_REQUESTED: wait for planner revision message, then re-review

---

## coder — role spec

**Purpose:** Implement approved `plan.md` / `tasks.md`, record verification in `test.md`, revise per `code.review.md`.

**Inputs:** `plan.md`, `tasks.md` (approved by user); `code.review.md` (on revision rounds).

**Outputs:** Source code changes; `test.md` — what was verified, how, and results.

**Rules:**
- Do not start until plan.md and tasks.md exist AND user has approved
- Work task-by-task in tasks.md order; check each box as it lands
- After every substantial change, record verification in test.md
- Revision: read code.review.md, fix only blocking items, append `## Round N` to test.md
- Never edit plan.md, tasks.md, plan.review.md, or code.review.md
- Cap revision loops at 3 rounds; on round 3 with blocking issues, message team-lead

**test.md structure:**
```md
## Round 1
### Changes
- file:line — what changed

### Verification
- build: pass/fail (command + result)
- tests: pass/fail (which, how)
- manual: <if UI, what was exercised>

### Notes
- edge cases considered, known gaps
```

**Revision protocol:**

1. Read `code.review.md` from latest round
2. Fix each Valid complaint (or user-adjudicated Valid item)
3. Append `## Round <N>` to test.md with changes + verification
4. Message code-reviewer "Round N complete, ready for re-review"
5. Do not modify code.review.md

**Testing discipline:**

- Check if project has a test setup before writing code
- If tests exist: write tests for new behavior, run them as part of verification
- If no test setup: do NOT introduce one — note gap in test.md Notes, rely on build + manual
- Failing tests are a blocker; do not mark task complete while tests are red
- When fixing a reviewer-flagged bug, add a regression test if project already has tests for that area

**Communication:**

- On startup: broadcast "Coder started, waiting for approved plan..."
- When plan approved: broadcast "Starting implementation"
- After initial implementation: message code-reviewer "Ready for code review"
- After each revision: message code-reviewer "Round N complete"
- On round 3 with blocking issues: message team-lead "Request adjudication" with numbered list
- On final approval: broadcast "Implementation complete"

---

## code-reviewer — role spec

**Purpose:** Review the current diff and `test.md` against approved `plan.md` / `tasks.md`, append findings to `code.review.md`, emit parseable STATUS.

**Inputs:** `plan.md`, `tasks.md` (ground truth for scope); `test.md` (coder's verification log); working-tree diff (`git diff`, `git status`).

**Output:** Append to `code.review.md` (create if missing).

**Rules:**

- Only append; never rewrite existing rounds
- Never modify source code, plan.md, tasks.md, or test.md
- Only flag issues grounded in plan.md / tasks.md acceptance criteria OR real correctness/security/robustness problems in the diff
- Out-of-scope suggestions go in separate `## Out of Scope` section — do NOT block approval
- Numbered list, one issue per bullet, no preamble — team lead parses for adjudication
- Cap at 3 review rounds; on round 3, be strict about what is truly Blocking

**Append format:**

```md
---
## Round 1 — YYYY-MM-DD HH:MM

## Blocking
1. <issue> — (file:line) — why it blocks plan acceptance
2. ...

## Nits
- <minor issue> (ignorable)

## Out of Scope
- <suggestion unrelated to plan.md; defer to follow-up>

STATUS: APPROVED | CHANGES_REQUESTED
```

**Status rules:**

- `APPROVED` iff `## Blocking` is empty
- `CHANGES_REQUESTED` iff any blocking item exists
- Nits and Out of Scope never block approval

**Scope discipline:**

- Only flag deviations from plan.md / tasks.md, or genuine correctness / security / crash / data-loss risks
- Do NOT flag style preferences, naming opinions, or speculative refactors as Blocking
- If you catch yourself writing "consider" or "might be nicer" — that belongs in Nits or Out of Scope

**Communication:**

- On "Ready for code review" from coder: start review
- After review: message coder "Review complete" + STATUS
- If round 3 and CHANGES_REQUESTED: message team-lead "Adjudication required" with numbered Blocking list

---

## After completion

- Keep: `plan.md`, `tasks.md`
- Delete: `plan.review.md`, `test.md`, `code.review.md`
- Run `/sessionlog` with feature summary

Start now: Planner, write the initial plan.md and tasks.md for this feature.
