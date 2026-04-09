---
name: flutter-animation-guide
description: Designs gesture-driven Flutter animation systems using direct manipulation, render loop architecture, motion primitives, and state machines. Use when the user asks for Flutter animation architecture, gesture interaction design, drag or swipe behavior, bottom sheets, carousels, overscroll or bounce behavior, scroll physics, spring or decay tuning, reduced-motion fallbacks, motion reviews, or wants conceptual guidance before implementation. Default to architecture-first guidance, then map to Flutter code when the task is implementation-oriented.
---

# Flutter Animation Guide

Use this skill as a standalone handbook for designing motion systems before writing Flutter code.

Treat motion as interaction architecture, not as decorative animation layered on after the fact.

## When To Use This Skill

Use this skill when the user needs to:
- design a gesture-driven interaction before implementation
- review an existing Flutter motion system
- choose between spring, decay, snap, or boundary behavior
- define gesture phases, thresholds, or state transitions
- reason about interruption, motion feel, or responsiveness
- add reduced-motion and fallback behavior to an interaction
- implement or fix a Flutter interaction without losing motion quality

Default to interaction architecture over ornamental motion, framework-first answers, or unstructured callback chains.

## Core Principles

1. `direct manipulation`
During active touch, content should usually track the finger directly. Add lag only when the feel intentionally calls for softness, mass, or stretch.

2. `press / follow / release / settle`
Model interaction as a lifecycle. Press confirms contact. Follow preserves control. Release resolves meaning. Settle lets motion communicate the result.

3. `render loop`
Collect input first. Process it inside one coordinated update pass. Separate input intake from state resolution and visual commitment.

4. `fixed-step simulation`
Use fixed-step stepping for interruption-sensitive spring motion so behavior stays stable under frame variation.

5. `analytical decay`
Use analytical decay for momentum when position and velocity should be predictable from elapsed time.

6. `state machine`
Use explicit states when gesture meaning changes by threshold, timer, direction, or release outcome.

7. `reduced motion`
Keep the logic and destination. Shorten or skip the visual journey when reduced motion is requested.

## How To Answer

1. Identify the request type:
- interaction design
- motion review
- motion primitive selection
- gesture state design
- accessibility review
- Flutter mapping after architecture is clear

2. Read only the relevant reference files.

3. Answer with structure and behavior before naming framework APIs.

4. Use pseudocode, formulas, thresholds, and decision rules before implementation details.

5. If the task is implementation-oriented, add concrete Flutter classes, widgets, controllers, or recognizers after the interaction model is clear.

## Which Reference To Read

Read the smallest relevant set.

- [interaction-model.md](references/interaction-model.md)
Use for direct manipulation, gesture phases, feedback loops, and control transfer.

- [render-loop-architecture.md](references/render-loop-architecture.md)
Use for coordinated updates, frame scheduling, fixed-step stepping, interruption handling, and render-loop structure.

- [motion-primitives.md](references/motion-primitives.md)
Use for spring motion, analytical decay, rubber banding, bounce-back, snap targeting, and velocity transfer.

- [interaction-states.md](references/interaction-states.md)
Use for touch slop, long press timing, axis lock, velocity windows, thresholds, and release resolution.

- [accessibility-and-fallbacks.md](references/accessibility-and-fallbacks.md)
Use for reduced motion, visible alternatives, touch targets, and fallback paths.

- [review-checklist.md](references/review-checklist.md)
Use when reviewing an existing motion design, architecture, or implementation plan.

## Default Response Format

Unless the user asks for something narrower, use this structure:

```md
## Interaction model
## State machine
## Motion primitives
## Render/update loop
## Accessibility and fallbacks
## Implementation notes
```

Guidance for each section:
- `Interaction model`: explain what the user should feel and when control shifts from finger to system
- `State machine`: name the states, timers, thresholds, and release outcomes
- `Motion primitives`: choose the right primitive and justify why it matches the behavior
- `Render/update loop`: explain how input is collected, resolved, simulated, and committed to UI state
- `Accessibility and fallbacks`: cover reduced motion and non-gesture paths for important actions
- `Implementation notes`: list tradeoffs, instrumentation, risks, and only then optional Flutter mapping

## Pseudocode Skeleton

Use this skeleton when describing a coordinated motion system without committing to Flutter APIs:

```text
on_input(event):
  buffer.store(event)
  schedule_frame_once()

frame(now):
  read buffered events
  update interaction state
  update motion targets
  step fixed-step simulation if needed
  compute analytical decay if needed
  write visual state
  clear consumed events
  if motion is still active:
    schedule_frame_once()
```

For more complex interactions, expand the frame like this:

```text
frame(now):
  step 1: consume input
  step 2: perform geometry reads if needed
  step 3: resolve gesture state transitions
  step 4: update motion targets and primitives
  step 5: commit visual output
  step 6: clear one-frame inputs
```

## Translation Rules For Flutter

When mapping the design into Flutter:
- map the render loop to a coordinated state-update pipeline
- keep input collection and motion stepping conceptually separate
- preserve direct manipulation during touch-heavy phases
- treat springs as stateful motion, not as duration-based decoration
- describe architecture before choosing specific classes or widgets

## Review Rules

When reviewing a Flutter motion design or plan:
- check whether the touch phases are separated cleanly
- check whether state transitions are explicit
- check whether the system can be interrupted safely
- check whether reduced motion preserves outcome while reducing travel
- check whether the motion primitive matches the intended behavior

## Common Misreads To Avoid

Avoid these incorrect assumptions:
- "all motion should use springs"
- "lag always feels more natural than direct tracking"
- "reduced motion means disabling the interaction"
- "render loop thinking requires custom rendering everywhere"
- "gesture handling can stay implicit if the UI seems simple"

## When Code Is Actually Requested

If the user explicitly asks for code, or clearly wants implementation:
- keep the structure above
- add a final `Flutter mapping` section
- only then mention concrete classes, controllers, gesture recognizers, or widget structure
- keep the code aligned with the architecture already described
