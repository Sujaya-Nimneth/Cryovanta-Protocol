# ADR-0003: Contact-gated touchdown and impact damage

## Status

Accepted — 2026-11-20

## Context

Radar altitude was treated as wheel contact, and mission completion accepted an airborne ship 20 metres above terrain. Repeated per-tick landing damage depended on frame duration.

## Decision

The simulation root performs a short radial terrain query against the baked terrain collision layer and supplies measured surface clearance plus a physical contact flag. The gear model establishes weight-on-wheels only after contact persists for 0.15 seconds with at least 95% deployment. Impact damage is applied once per touchdown episode using excess sink rate and gear state. Mission completion requires deployed gear, weight-on-wheels, clearance at most 0.5 metres, total speed at most 5 m/s, and sink rate at most 3 m/s.

## Alternatives considered

- Lower the radar threshold: rejected because radar clearance is not physical contact.
- Per-tick damage while near terrain: rejected because it is frame-duration dependent and damages hovering aircraft.

## Consequences

Direct gear tests can inject contact explicitly. Live tests use real baked terrain. Radar remains a guidance signal, not a contact oracle. Device landing behavior remains a separate verification requirement.

## Verification

Airborne completion is rejected; radar-only contact is rejected; stable contact completes; hard and gear-up impacts apply once; repeated contact ticks do not repeat damage.
