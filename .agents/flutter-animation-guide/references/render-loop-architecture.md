# Render Loop Architecture

## Contents
- Purpose
- Why use a coordinated update path
- The core loop
- Event collection
- The frame pipeline
- Fixed-step simulation
- Interruption handling
- Batched reads and writes
- Render loop without a dedicated engine layer
- Pseudocode templates
- Flutter translation notes

## Purpose

Use this reference when the user asks how to structure interaction and motion logic, not just how to animate a single value.

## Why Use A Coordinated Update Path

A gesture-driven motion system becomes fragile when input handling, gesture meaning, motion stepping, and visual updates are scattered across unrelated callbacks.

A coordinated update path helps with:
- predictable state transitions
- safe interruption
- stable motion feel
- cleaner ownership between input and motion
- easier debugging and review

## The Core Loop

Use a loop like this when motion remains active across frames:

```text
on_input(event):
  store event in a buffer
  request one frame if none is pending

frame(now):
  consume buffered input
  update interaction state
  update motion targets
  advance active motion systems
  commit visual output
  clear one-frame input
  if anything still moves:
    request another frame
```

The point is not a specific function name. The point is coordinated responsibility.

## Event Collection

Event collection avoids three common problems:
- state changes happening out of order
- gesture meaning being resolved in too many places
- input handlers performing logic that belongs in the update pass

Collect input first. Resolve meaning inside the frame.

```text
on_pointer_move(event):
  pending_move = event
  schedule_frame_once()
```

## The Frame Pipeline

A useful pipeline for complex interactions is:

```text
frame(now):
  step 1: consume input
  step 2: perform geometry reads if needed
  step 3: resolve state transitions
  step 4: update motion targets
  step 5: advance active motion
  step 6: commit visual output
  step 7: clear consumed input
```

This keeps ownership legible.

## Fixed-Step Simulation

Use fixed-step simulation when spring motion must stay stable under frame-rate variation.

```text
accumulator += frame_delta
while accumulator >= step_ms:
  advance_simulation(step_ms)
  accumulator -= step_ms
```

Why it helps:
- tuning remains consistent
- interruption behaves predictably
- motion is less dependent on display timing noise

Use a small fixed step. A practical default for UI motion is often in the low millisecond range.

## Interruption Handling

Assume ongoing motion can be interrupted at any time.

Typical interruption patterns:
- the user touches during settle and regains control
- a new target replaces the old target mid-flight
- a decaying motion hits a boundary and changes primitive

```text
on_new_contact_during_motion:
  capture current visual state
  stop or rebase active motion
  return control to input-driven updates
```

## Batched Reads And Writes

Keep geometry reads, logic, and visual commits conceptually separate.

A useful discipline is:
- read once
- compute in memory
- commit visual changes together

That separation makes the interaction easier to reason about and less likely to accumulate hidden coupling.

## Render Loop Without A Dedicated Engine Layer

Render-loop thinking does not require a formal engine abstraction.

Use the pattern even if the codebase only needs:
- a shared scheduling helper
- a local buffer for one interaction
- a coordinated update function inside one feature

What matters is the structure of ownership, not whether there is a separate engine module.

## Pseudocode Templates

`minimal coordinated loop`

```text
buffer = {}
frame_pending = false

on_input(event):
  buffer.store(event)
  if not frame_pending:
    frame_pending = true
    request_frame()

frame(now):
  frame_pending = false
  process_input(buffer)
  update_state()
  step_motion()
  write_ui()
  buffer.clear()
  if motion_active:
    request_frame()
```

`loop with explicit stages`

```text
frame(now):
  consume_input()
  read_geometry()
  resolve_state_machine()
  update_targets()
  step_fixed_motion()
  apply_visual_output()
  clear_input()
```

## Flutter Translation Notes

When mapping this design into Flutter:
- think in terms of a coordinated state-update pipeline
- keep input collection separate from motion resolution
- let the architecture decide the implementation, not the other way around
