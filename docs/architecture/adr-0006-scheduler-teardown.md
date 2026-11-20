# ADR-0006: Non-recursive scheduler teardown

## Status

Accepted — 2026-11-20

## Context

Scheduler shutdown held its mutex while calling a public cancellation method that locked the same mutex. Godot 4.7.2 currently permits recursive locking, but the code relies on an unnecessary implementation detail.

## Decision

Cancellation logic lives in an unlocked helper. Public cancellation acquires the mutex once; shutdown acquires it once, marks the scheduler stopped, calls the helper, releases the mutex, wakes all workers, and joins them. No worker callback runs while the scheduler mutex is held.

## Alternatives considered

- Rely on recursive mutex behavior: rejected as fragile and engine-version dependent.
- Unlock around the public call: rejected because it introduces a shutdown race.

## Consequences

The existing four-worker and 64-slot contracts remain unchanged. Teardown is deterministic and safe under concurrent submit/cancel/poll activity.

## Verification

Concurrent teardown stress, worker join, slot reclaim, and post-shutdown submit rejection.
