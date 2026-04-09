# Accessibility And Fallbacks

## Contents
- Purpose
- Reduced motion
- Visible fallback paths
- Touch target size
- Alternatives for important actions
- Announcing state changes
- Review heuristics
- Pseudocode patterns
- Flutter translation notes

## Purpose

Use this reference when the user asks how to make gesture-heavy motion systems more robust and inclusive.

## Reduced Motion

Reduced motion should preserve outcome while reducing travel.

That means:
- the interaction still works
- the final destination is still correct
- only the visual journey is shortened or skipped

```text
resolve interaction outcome
if reduced_motion:
  commit end state immediately
else:
  run the designed motion path
```

Reduced motion is not a reason to remove the interaction entirely.

## Visible Fallback Paths

Important actions should not be gesture-only.

Examples of important actions:
- delete
- close
- confirm
- undo
- refresh

Provide a visible path that does not depend on discovering a hidden gesture.

## Touch Target Size

Use sensible minimum touch targets.
Common references are:
- `44 x 44 px`
- `48 x 48 dp`

The visible element may be smaller, but the interactive region should still be easy to hit reliably.

## Alternatives For Important Actions

Fallback design is not only about input modality. It is also about discoverability.

Review questions:
- can the user complete the task without guessing a hidden gesture?
- does a revealed action also exist as a visible action when the task matters?
- does a drag-only interaction expose another path for important outcomes?

## Announcing State Changes

Gesture-heavy interfaces often communicate with motion first. Do not rely on motion or color alone when a state change matters.

Important states to surface clearly include:
- refresh started
- item dismissed
- selection changed
- drag mode active
- operation completed or cancelled

## Review Heuristics

Check these even when the user does not ask:
- reduced motion preserves outcome while shortening the path
- important actions have visible alternatives
- touch targets are large enough
- state changes are not communicated only through motion or color
- the interaction remains understandable without gesture discovery alone

## Pseudocode Patterns

`reduced motion gate`

```text
resolve outcome
if reduced_motion:
  snap to resolved state
else:
  run full motion
```

`important action fallback`

```text
if action_is_important:
  provide visible action path
  provide gesture path as enhancement
```

## Flutter Translation Notes

When mapping this into Flutter:
- decide fallback paths at the interaction-design level first
- treat reduced motion as a system behavior rule, not as a late animation tweak
- include semantics and discoverability in the architecture review, not as a final patch
