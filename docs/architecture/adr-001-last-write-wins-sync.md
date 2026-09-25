---
ontology: true
type: decision
domain: sync
summary: Task sync resolves conflicts by newest edit (Task.modifiedAt) and deletes via isPurged tombstones
status: active
tags: [sync, firestore, hive, conflicts]
related: [adr-002-server-authoritative-premium]
discovered: 2026-09-24
verified: true
---

# ADR-001: Last-write-wins task sync with tombstones

## Status
Accepted (2026-09-24)

## Context
Tasks are local-first (Hive) and mirrored to Firestore. The startup upload overwrote the
cloud copy of every task with the device's copy, so an edit made on another device was lost
whenever an older device opened the app. Permanently deleted tasks reappeared because the
cloud document was removed while other devices still held a local copy and re-uploaded it.
Constraints: offline-first, several devices per user (Android + web), no custom server for sync.

## Decision
- Every task carries `modifiedAt` (Hive field 24), set by `Task.touch()` on each user edit.
  Cloud edit time = `modifiedAt ?? updatedAt`.
- On sync, the newer edit wins in both directions; the startup upload only sends tasks newer
  than a per-user watermark. Task writes use `merge: true`.
- Permanent delete writes an `isPurged` tombstone instead of deleting the document, so every
  device learns about the deletion.

## Rationale
1. Deterministic and cheap: one timestamp comparison, no server logic, works offline.
2. Matches user expectation ("my latest change sticks") for single-user data.
3. Tombstones are the only way to propagate deletes to devices that were offline.

## Trade-offs
- Concurrent edits to different fields of the same task on two devices: the older one is lost.
- Clock skew between devices can pick the wrong winner.
- Tombstones stay in Firestore (small documents).

## Consequences
- **Positive**: No more resurrected deletions or clobbered edits; sync is idempotent.
- **Negative**: No field-level merge.
- **Mitigation**: Tasks are edited by one person, conflicts are rare; revisit if collaboration
  or shared lists are added (field-level merge or server timestamps).

## Revisit trigger
Shared/collaborative tasks, or reports of lost edits.
