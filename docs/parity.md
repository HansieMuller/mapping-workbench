# Feature checklist

MappingWorkbench processes workbooks through context selection → upload → worksheet preview → per-sheet mapping → background import → persisted outcomes and live progress. Its services handle identity resolution, relational upserts, row transactions, provenance and recovery. All results use the batch-selected race.

| Capability | Implementation | Engineering detail |
| --- | --- | --- |
| Context → upload → preview → mapping → queue → progress → results | Complete | Server-rendered wizard; event/race creation persists transactionally |
| XLSX and every worksheet, header candidates, samples, letters beyond Z, unnamed columns | Complete | Human confirmation/correction of headers; suggestions use explicit alias evidence |
| 17 destinations plus Unused, explicit aliases, duplicate/prerequisite guards | Validated | Per-sheet UI and server validation reject crafted indexes and destinations |
| Passport | Service-level support | Tested internally; the mapping dropdown contains 17 fields |
| Typed cells, dates, time fractions/seconds/durations and status aliases | Validated | Invalid supplied values fail explicitly; workbook display text remains separate |
| Result, registration, profile, unsupported and blank classification | Complete | Registration/profile rows create no results; blank rows persist as skipped for truthful counters |
| Raw and mapped provenance | Complete | Sheet, row, column letter/header, cell type/value and normalized values retained separately |
| ID → passport → name/birth identity precedence | Validated | Reject material name/birth/identifier conflicts |
| Fill missing only, permanent number as attribute, club memberships | Complete | Permanent number is not an identity key; normalized club and membership uniqueness enforced |
| Ambiguous name-only identities | Guarded | Batch-local identity without DOB/strong ID; later batches reject ambiguous matches rather than guessing |
| Race-number upsert across batches | Complete | Preserve first creating batch; reject race number reassignment to another athlete |
| No race number | Complete | Match batch/race/athlete only; separate results across batches |
| Time display/seconds, positions, category and age at event | Complete | Event date and birth date determine age |
| Per-row transactions and partial success | Complete | Earlier committed rows survive failed rows; failure provenance persists outside rolled-back work |
| Background claim and replay | Guarded | PostgreSQL advisory ownership, persisted claim token, terminal-row checkpoints and explicit resume; no exactly-once claim |
| Unique-conflict retries | Validated | Whole row retries outside rolled-back savepoint, verified with competing PostgreSQL sessions |
| Upload/archive limits; malformed/formula/external-reference handling | Validated | Bounded archive inspection before Roo; reject formulas and external references without fetching/executing |
| Authentication, authorization, CSRF, websocket ownership | Validated | Rails password/session auth, owner-only batches/uploads/channels; default storage routes disabled |
| Audit uploader, history/search/pagination, details/errors | Complete | PaperTrail attribution and escaped server/DOM output |
| Production integrations and unrelated application features | Out of scope | Local fictional domain and fixtures; no production integrations |

See [verification evidence](evidence.md) for actual results and limitations. The implementation and review history are recorded in [PR #4](https://github.com/HansieMuller/mapping-workbench/pull/4).
