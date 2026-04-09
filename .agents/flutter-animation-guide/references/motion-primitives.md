# Motion Primitives

## Contents
- Purpose
- Choosing the right primitive
- Spring motion
- Analytical decay
- Velocity transfer
- Rubber banding
- Bounce-back
- Snap targeting
- Primitive selection heuristics
- Pseudocode patterns
- Flutter translation notes

## Purpose

Use this reference when the user asks what kind of motion should drive a behavior.

Pick primitives by meaning, not by habit.

## Choosing The Right Primitive

Use the primitive that matches the job:
- `spring` for return, attachment, redirect, and interruption-friendly motion
- `analytical decay` for momentum and coast behavior
- `rubber banding` for boundary resistance during active pull
- `bounce-back` for returning from invalid positions
- `snap targeting` for settling into discrete resting values

## Spring Motion

A damped spring works well when the system should stay responsive to interruption.

```text
force = -k * (position - target) - b * velocity
acceleration = force
velocity += acceleration * dt
position += velocity * dt
```

Interpretation:
- `stiffness` controls how strongly the system pulls toward the target
- `damping` controls how quickly oscillation dies out

Use spring motion when:
- the target may change while motion is active
- the user can interrupt mid-flight
- the motion should feel state-based instead of duration-based

## Analytical Decay

Analytical decay is useful for momentum because position and velocity can be computed directly from time.

```text
lambda = -c * ln(friction)
position(t) = start + (v0 / lambda) * (1 - exp(-lambda * t))
velocity(t) = v0 * exp(-lambda * t)
```

Use analytical decay when:
- the motion should coast naturally after release
- you want predictable position and velocity at any moment
- the motion should feel like friction rather than attraction

The constant multiplier in the lambda conversion should match the feel model used in the product. Keep it consistent.

## Velocity Transfer

Recent release velocity often becomes the initial condition for post-release motion.

That preserves continuity between user control and system control.

```text
recent_velocity = sample_recent_history(window_ms)
start_motion(v0 = recent_velocity)
```

Use a recent sampling window, not the full gesture duration. A sensible default is roughly `80-120 ms`.

## Rubber Banding

Rubber banding is boundary resistance during active user control.

It is not the same as bounce-back.

```text
rubber(distance, range) = (distance * c * range) / (range + c * distance)
```

Use it when the user pulls beyond a valid region and the interface should resist while still feeling continuous.

## Bounce-Back

Bounce-back is the return to a valid boundary after control transfers away from the finger.

It often starts from the rubber-banded display position and then hands off to a spring.

```text
if released_out_of_bounds:
  spring.position = display_position
  spring.target = nearest_valid_boundary
  spring.velocity = damped_entry_velocity
```

The handoff should feel continuous rather than like a reset.

## Snap Targeting

Snap targeting is useful when the system has discrete resting values.

Common pattern:
- collect recent release velocity
- estimate direction or resting intention
- choose the target slot
- use spring motion to settle into it

## Primitive Selection Heuristics

```text
if the surface is under the finger:
  prefer direct manipulation

if motion happens after release and should coast:
  prefer analytical decay

if motion should return, redirect, or stay interruptible:
  prefer spring

if the user is pulling past a boundary:
  use rubber banding

if content must return from an invalid region:
  use bounce-back

if there are discrete resting slots:
  use snap targeting
```

## Pseudocode Patterns

`decay into bounce-back`

```text
start decay from release velocity
while decaying:
  compute position and velocity from elapsed time
  if boundary is crossed:
    switch to bounce-back spring
```

`direct drag into spring settle`

```text
on_drag:
  visual_position = pointer_position

on_release:
  spring.position = visual_position
  spring.target = resolved_target
  spring.velocity = recent_velocity
```

`pull into commit or cancel`

```text
on_pull:
  if within bounds:
    display = raw_distance
  else:
    display = rubber(raw_distance, range)

on_release:
  if threshold_passed:
    commit_action()
  else:
    return_to_rest()
```

## Flutter Translation Notes

When mapping these ideas into Flutter:
- pick the primitive by interaction meaning first
- keep formulas and transition rules stable before naming framework objects
- avoid replacing interruption-sensitive motion with arbitrary durations unless the interaction truly does not need interruption
