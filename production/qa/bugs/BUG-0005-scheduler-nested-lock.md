# BUG-0005 — Scheduler shutdown nests mutex locks

**Severity:** S3-Medium  
**Priority:** P2  
**Status:** Verified Fixed (Phase 1 `8d07a5d`)  
**Build:** `624b68e`

## Reproduction

1. Call `ChunkTaskScheduler.shutdown()`.
2. It locks `_mutex`, then calls `cancel_all_jobs()`, which locks the same mutex again.

**Expected:** Lock ownership is explicit and portable; shutdown is safe under concurrent submit/cancel/poll.  
**Actual:** Nested locking relies on recursive mutex behavior. Godot 4.7.2 permits it in the probe, so this is not a confirmed deadlock.

**Files:** `ChunkTaskScheduler.gd`
