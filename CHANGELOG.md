# Changelog

## 0.2.1.0 — 2026-10-15

- Preserve existing numbered-result fields when correction columns are Unused, absent or blank; apply nonblank replacements, including a valid zero time, while retaining creating-batch attribution and row audit history.
- Store canonical finish-status aliases and reject unrecognized statuses through model validation. Failed result rows roll back athlete, club, membership, result and audit writes while preserving failure provenance and processing later rows.
- Add authenticated generated-XLSX correction, status, rollback and replay regressions, plus model-level coverage for every supported alias and optional blank statuses. Keep unnumbered matching/replacement and registration/profile classification unchanged.

## 0.2.0.0 — 2026-10-15

- Import every worksheet through an authenticated context, upload, header preview, mapping, queue and live progress workflow.
- Reconcile fictional athletes, clubs, memberships and selected-race results, retaining typed provenance, partial success and uploader audit history.
- Reject unsafe archives, invalid values, crafted mappings and conflicting identities. Fence duplicate/disconnected workers and resume uncommitted rows without repeating terminal checkpoints.
- Add generated multi-sheet examples, competing PostgreSQL session regressions and real Chrome/Redis/Sidekiq/ActionCable evidence.
- Provide pinned local services, safe cleanup, a shared local/hosted CI command and setup, architecture, mapping, recovery and demonstration documentation.
- Keep development demo seeds and credentials isolated from fresh test-database preparation.

## 0.1.0.0 — 2026-10-15

- Publish a runnable Rails scaffold and mapping workflow feature checklist on `main`.
