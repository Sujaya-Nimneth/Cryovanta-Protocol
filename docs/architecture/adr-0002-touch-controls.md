# ADR-0002: Visible six-axis touch controls

## Status

Accepted — 2026-11-20

## Context

The controller exposed heave and roll registers, but every real gesture passed zero for both axes. The action labels were hidden until a stick was touched.

## Decision

Retain the two lower-corner virtual sticks for translation and pitch/yaw. Add a persistent left-edge heave slider and right-edge roll slider, each independently tracked by touch index. Add persistent MODE, FIRE, and REWIND action zones. Controls are drawn whenever the simulation HUD is active, with persistent labels. Dragging upward/rightward is positive; release clears only the released control.

## Alternatives considered

- Modifier gestures on existing sticks: rejected because discoverability and multitouch ownership become ambiguous.
- Four simultaneous virtual sticks: rejected because lower-corner space is too crowded on phones.

## Consequences

The overlay owns four tracked touch indices and two scalar deflections. HUD safe-area geometry and input hit regions share the same layout constants. Existing lower-corner stick behavior remains compatible.

## Verification

Press/drag/release tests exercise heave and roll through the live input host, including simultaneous controls and independent release.
