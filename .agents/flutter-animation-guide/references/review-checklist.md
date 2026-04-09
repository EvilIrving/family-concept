# Review Checklist

## Contents
- Purpose
- Architecture review checklist
- Motion primitive review checklist
- Accessibility review checklist
- Common mistakes
- Suggested review output

## Purpose

Use this reference when reviewing a Flutter motion system, an animation proposal, or an interaction spec.

## Architecture Review Checklist

Check these first:
- does the design separate `press`, `follow`, `release`, and `settle`?
- is there a clear handoff from user control to system control?
- is gesture meaning modeled with explicit states?
- is the update path coordinated, or is logic scattered across unrelated callbacks?
- can ongoing motion be interrupted safely?
- does the plan distinguish direct manipulation from stylized lag?

## Motion Primitive Review Checklist

Check whether the primitive matches the behavior:
- spring for return, attachment, or interruption-friendly redirection
- analytical decay for momentum and coast behavior
- rubber banding during active overscroll
- bounce-back after release or boundary resolution
- snap targeting for discrete resting values
- velocity transfer from recent input rather than whole-gesture averaging when feel matters

## Accessibility Review Checklist

Check these even when the user did not ask:
- reduced motion preserves the result while shortening the path
- important actions have visible alternatives
- touch targets are large enough
- state changes are not conveyed only through motion or color
- discoverability is reasonable for important actions

## Common Mistakes

Catch these mistakes early:
- delayed follow during interactions that should use direct manipulation
- duration-based animation where interruption-sensitive motion needs state-based behavior
- missing reduced motion handling
- mixing event handling, state transitions, and rendering in a way that hides ownership
- unclear or implicit state transitions
- treating overscroll resistance and bounce-back as the same thing
- sampling velocity too broadly and losing release feel
- choosing motion primitives by fashion rather than behavior

## Suggested Review Output

Use this format when reviewing:

```md
## Interaction model
What the user controls directly, when the system takes over, and whether the feel matches the intended behavior.

## State machine
The states, thresholds, timers, and transitions that are missing, unclear, or correct.

## Motion primitives
Whether spring, decay, rubber banding, bounce-back, or snap targeting are being used appropriately.

## Render/update loop
Whether the design has a coherent input-to-frame pipeline and safe interruption handling.

## Accessibility and fallbacks
Whether reduced motion and non-gesture paths are handled correctly.

## Implementation notes
Tradeoffs, risks, instrumentation, and optional Flutter mapping notes.
```
