---
description: Run the full plan→review→code→review pipeline for a feature, with human gates and a capped silent code-review loop.
---

# /feature

Drive a feature end-to-end through the planner/reviewer/coder/reviewer pipeline with explicit artifacts and human approval gates.

**Feature request:** $ARGUMENTS

## Artifacts (all at repo root, created on demand)
- `plan.md` — approach (planner writes)
- `tasks.md` — checklist (planner writes)
- `plan.review.md` — plan reviewer findings (append-only)
- `test.md` — coder verification log (append-only across rounds)
- `code.review.md` — code reviewer findings (append-only)

## Roles
- **planner** and **coder** — YOU (the main orchestrator) adopt these roles so context is preserved across rounds. Read `.claude/agents/planner.md` and `.claude/agents/coder.md` and follow those specs when acting in those roles.
- **plan-reviewer** and **code-reviewer** — dispatch as subagents via the Agent tool (fresh context each round). Their specs are in `.claude/agents/`.

## Pipeline

### Phase 1 — Plan (human-gated loop)

1. Adopt the **planner** role. Write `plan.md` and `tasks.md` for the feature.
2. Show the user a 5-line summary and ask via `AskUserQuestion`:
   - `Send to reviewer`
   - `Approve as-is (skip review)`
   - `I have edits` (user provides feedback; loop back to step 1)
   - `Abort`
3. If "Send to reviewer": dispatch **plan-reviewer** subagent. It appends to `plan.review.md` and ends with `STATUS: APPROVED` or `STATUS: CHANGES_REQUESTED`.
4. Show the user the new review block and ask:
   - `Apply suggestions` (planner role revises plan.md/tasks.md, then loop to step 3)
   - `Approve plan as-is` (ignore remaining suggestions)
   - `I have edits` (user feedback, loop to step 1)
   - `Abort`
5. On approval: delete `plan.review.md`. Proceed.

### Phase 2 — Code (silent loop, capped at 3 rounds)

6. Adopt the **coder** role. Implement tasks in order. Write round 1 to `test.md`.
7. Dispatch **code-reviewer** subagent. It reads the diff + `test.md` + `plan.md` + `tasks.md` and appends to `code.review.md` ending with a STATUS line.
8. Parse the STATUS line:
   - `APPROVED` → go to Phase 3.
   - `CHANGES_REQUESTED` and round < 3 → as **coder**, fix Blocking items, append a new round to `test.md`, go to step 7.
   - `CHANGES_REQUESTED` and round == 3 → go to **Adjudication Gate**.
9. (removed — no loop.log.md)

### Adjudication Gate (only on round-3 failure)

10. Parse the numbered `## Blocking` list from the latest `code.review.md` round.
11. Present each item to the user via `AskUserQuestion` with options: `Valid (fix)` / `Nitpick (ignore)` / `Defer (new task)`.
12. For `Defer` items, append them to `tasks.md` as unchecked follow-up tasks.
13. Run one final coder round on only the `Valid` items. Write to `test.md`. Go to Phase 3 (skip re-review).

### Phase 3 — Final approval

14. Show the user a summary: files changed, LOC, rounds taken, deferred items.
15. `AskUserQuestion`:
    - `Approve` — mark completed tasks in `tasks.md` as checked, delete `test.md` and `code.review.md`, call `/sessionlog` to record the session summary, leave `plan.md` and `tasks.md` for history, DONE.
    - `Request changes` — user provides feedback, coder runs one more round.
    - `Abort` — leave artifacts in place, report.

## Operating rules for YOU, the orchestrator
- At every `AskUserQuestion` gate, keep summaries to ≤5 lines — the user can open the file themselves.
- Never delete an artifact without the user having approved it.
- If the user says "I have edits" without specifying, ask a focused follow-up.
- Between code rounds, remind yourself (in the adopted coder role): scope is plan.md, not the reviewer's opinions. Defer, don't absorb.
- If any phase errors unexpectedly (missing file, tool failure), stop and surface to the user — do not paper over.
