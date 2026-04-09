# Interaction Model

## Contents
- Purpose
- The baseline interaction contract
- The four-phase loop
- Direct manipulation
- Intentional lag and weighted follow
- Immediate feedback
- Control transfer
- Pseudocode patterns
- Flutter translation notes

## Purpose

Use this reference when the user is really asking about interaction feel rather than framework mechanics.

The core idea is simple: gesture systems should feel coherent to a human before they look elegant in code.

## The Baseline Interaction Contract

A strong interaction usually follows this contract:
- the interface acknowledges contact immediately
- the user keeps control while the finger is down
- the system resolves meaning on release or threshold crossing
- motion communicates the result after control transfers away from the finger

That contract prevents an interaction from feeling delayed, vague, or disconnected.

## The Four-Phase Loop

Use this loop as the default mental model:

```text
press:
  confirm contact immediately

follow:
  keep the surface under user control
  keep gesture interpretation open if needed

release:
  decide what happened
  tap, drag, fling, refresh, dismiss, snap

settle:
  let motion express the result
```

Interpretation notes:
- `press` builds trust
- `follow` preserves control
- `release` resolves meaning
- `settle` communicates consequence and continuity

## Direct Manipulation

Direct manipulation is the default for touch-heavy surfaces.

Use it when:
- the content should feel attached to the finger
- precision matters during drag
- the user expects immediate cause-and-effect
- the release should inherit recent velocity

```text
on_pointer_move:
  visual_position = pointer_position - grab_offset

on_pointer_up:
  release_velocity = sample_recent_velocity()
  start_settle_motion(release_velocity)
```

## Intentional Lag And Weighted Follow

Lag is not automatically bad. It is a design choice.

Use intentional lag when the goal is to make a surface feel:
- soft
- weighted
- elastic
- playful

Keep it explicit. If the user expects precision, lag becomes a flaw instead of a character choice.

```text
on_pointer_move:
  motion_target = pointer_position - grab_offset

on_frame:
  visual_position = move_toward(motion_target)
```

## Immediate Feedback

Contact should be acknowledged right away, even before gesture meaning is fully resolved.

Typical feedback channels:
- scale
- highlight
- ripple
- border or shadow shift
- status or phase indicator

This feedback complements user control. It should not replace it.

## Control Transfer

Do not blur the handoff between user-driven and system-driven motion.

During `follow`, the finger owns the motion.
During `settle`, a motion primitive owns the motion.

The transition should happen at a clear moment, such as:
- release
- threshold crossing followed by commitment
- entering a non-interactive post-release state

## Pseudocode Patterns

`direct drag into settle`

```text
on_drag:
  visual_position = pointer_position

on_release:
  state = settling
  start_motion_from_current_position()
```

`follow with weighted response`

```text
on_drag:
  target_position = pointer_position

on_frame:
  visual_position = approach(target_position)
```

`threshold-based commit`

```text
on_drag:
  show_progress_toward_commit()

on_release:
  if threshold_passed:
    commit_action()
  else:
    cancel_and_return()
```

## Flutter Translation Notes

When mapping this into Flutter:
- start by defining who owns motion in each phase
- preserve direct manipulation unless the feel explicitly calls for controlled lag
- model the handoff from finger to motion primitive as a behavior change, not just an animation start
