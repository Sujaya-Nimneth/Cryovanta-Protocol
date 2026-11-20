# Cryovanta Protocol — One-Sortie Brief

**Stage:** Production repair and improvement  
**Platform:** Android ARM64, Vulkan Mobile, landscape; desktop is a development and regression surface.

## Pitch

A procedural planetary flight-and-combat simulation where the player flies a six-degree-of-freedom vessel, reconnoiters a waypoint, intercepts drones, and lands safely.

## Core loop

1. Launch into an intentional, explained flight state.
2. Read the objective, controls, and flight instruments.
3. Reach the recon waypoint.
4. Destroy the required drones.
5. Deploy gear and complete a real touchdown.
6. See success or failure, then restart or replay.

## MVP requirements

- One coherent spawn profile; no unexplained zero-velocity freefall.
- Touch access to translation, pitch, yaw, heave, and roll.
- Rewind restores a coherent, documented state.
- Mission completion requires deployed gear and stable touchdown.
- Pause, restart, failure, and completion states.
- Readable numeric HUD, named guidance modes, persistent control labels.
- Basic engine, weapon, impact, warning, and UI feedback.
- Current Android build validated on a named device.

## Technical constraints

- Godot 4.7.2, GDScript, production scripts at most 250 lines.
- Preserve fixed pools, four-worker ceiling, floating origin, cube-sphere skirts, and std430 `vec4` layout.
- One render-frame governor sample per frame.
- Measure allocation and performance on device; headless static memory is not a GPU certificate.
- Offline single-player scope; no network, save progression, economy, or multiplayer in this plan.

## Build order

1. Truthful baseline, evidence, test manifest, CI, and budgets.
2. Regression-first governor, touch, landing, rewind, and scheduler fixes.
3. Playable sortie, HUD, recovery flow, controls guide, and feedback.
4. Device profiling, backend decision, allocation work, and soak.
5. Art/accessibility/balance polish, security audit, current APK, and release gate.

## Out of scope

Multiplayer, economy, save progression, new planets/biomes, large content packs, engine migration, and full studio ceremony.
