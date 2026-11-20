# ADR-0005: Proper load and local visual response

## Status

Accepted — 2026-11-20

## Context

The HUD labelled net force divided by weight as G-load, making gravity-only freefall read approximately 1 G. Visual roll used world-space angular Z and repeated node-path lookups.

## Decision

`g_load` means proper load: non-gravitational force magnitude divided by standard weight. Gravity-only freefall reads zero; hover reads approximately one. Coordinate acceleration remains available through force/velocity telemetry. Visual pitch and roll use ship-local angular velocity and cached plume references stored on the visual rig.

## Alternatives considered

- Keep net-force G and rename the HUD: rejected because flight and structural-load conventions use proper load.
- Continue world angular Z: rejected because response changes with attitude.

## Consequences

Historical tests that asserted net-force G are updated to the accepted contract. Thermal structural loading consumes proper load. Visual references are created once during rig construction.

## Verification

Freefall, hover, and thrust cases plus arbitrary-attitude local roll and cached-reference checks.
