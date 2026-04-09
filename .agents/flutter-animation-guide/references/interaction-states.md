# Gesture State Machines

## Contents
- Purpose
- Why state machines matter
- Sensible defaults
- Common interaction states
- Touch slop and gesture commitment
- Long press timing
- Axis lock
- Velocity windows
- State transition pseudocode
- Flutter translation notes

## Purpose

Use this reference when gesture meaning changes over time, by threshold, by timer, or by release outcome.

## Why State Machines Matter

A gesture is not just a stream of positions.
It is a stream of positions plus changing intent.

State machines make that intent explicit.
They answer questions like:
- is the finger merely down, or is the interaction already dragging?
- has long press already committed?
- are we still deciding the axis?
- did release resolve into tap, fling, cancel, or settle?

## Sensible Defaults

Use these as starting points, not as fixed law:
- touch slop: `8-12 px`
- long press: `400-500 ms`
- tap max duration: `200-300 ms`
- double tap window: `250-350 ms`
- double tap distance: `20-30 px`
- velocity sampling window: `80-120 ms`

Tune them to platform feel and product needs, then keep them consistent.

## Common Interaction States

A practical baseline set is:
- `idle`
- `pressed`
- `dragging`
- `armed`
- `decaying`
- `bouncing`
- `refreshing`
- `tap`
- `long_press`
- `fling`

Not every interaction needs every state. Keep only states that change logic, control ownership, or visible behavior.

## Touch Slop And Gesture Commitment

Touch slop separates an uncertain press from a committed drag-like interaction.

Before slop is crossed:
- tap may still be valid
- long press may still be valid
- axis choice may still be undecided

After slop is crossed:
- commit drag behavior
- cancel press-only interpretations if needed

```text
if state == pressed and distance_from_down > touch_slop:
  state = dragging
  cancel_long_press_timer()
```

## Long Press Timing

Long press should only commit if movement remains within tolerance for long enough.

```text
on_pointer_down:
  state = pressed
  start_long_press_timer()

on_pointer_move:
  if movement_exceeds_touch_slop:
    cancel_long_press_timer()

on_timer_fire:
  if state == pressed:
    state = long_press
```

## Axis Lock

Axis lock prevents early diagonal wobble.

A simple strategy:
- wait until movement exceeds the commitment threshold
- compare horizontal and vertical displacement
- lock to the dominant axis for the rest of the gesture

```text
if not axis_locked and distance_from_down > touch_slop:
  if abs(dx) > abs(dy):
    axis = horizontal
  else:
    axis = vertical
```

## Velocity Windows

Velocity should usually come from recent motion, not from the full gesture history.

That keeps the release feel aligned with what the user just did.

```text
recent_history = last_samples(within = 100ms)
velocity = delta_position / delta_time
```

## State Transition Pseudocode

`generic draggable surface`

```text
idle -> pressed on pointer_down
pressed -> dragging when touch_slop is crossed
pressed -> tap on quick release
pressed -> long_press when the timer completes without disqualifying movement
dragging -> decaying on release with enough velocity
dragging -> settle on release with low velocity
decaying -> bouncing if a boundary is crossed
decaying -> idle when velocity is exhausted
bouncing -> idle when the return completes
```

`threshold-based commit`

```text
idle -> dragging on pull start
dragging -> armed when threshold is exceeded
dragging -> cancelled on release below threshold
armed -> committed on release
committed -> settling when follow-up work completes
settling -> idle when return motion finishes
```

## Flutter Translation Notes

When mapping this into Flutter:
- model the states before choosing gesture APIs
- let states decide what input is valid, what motion is active, and what the UI communicates
- keep timers and thresholds near the state logic instead of scattering them across callbacks
