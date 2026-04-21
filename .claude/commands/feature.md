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
2. Plan-reviewer reviews → human gate for approval
3. Coder implements → code-reviewer reviews (silent loop, max 3 rounds)
4. Round 3 deadlock → human adjudication
5. Final human approval → cleanup + `/sessionlog`

**Team lead responsibilities:**
- You (the user) are the team lead
- Use `Shift+Down` to switch between teammates
- Approve plan at gate 1, approve code at final gate
- On round-3 deadlock, adjudicate blocking items: Valid / Nitpick / Defer

**After completion:**
- Keep: `plan.md`, `tasks.md`
- Delete: `plan.review.md`, `test.md`, `code.review.md`
- Run `/sessionlog` with feature summary

Start now: Planner, write the initial plan.md and tasks.md for this feature.
