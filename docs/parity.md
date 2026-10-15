# Feature parity and deliberate improvements

The default source branch and importer call graph were inspected before implementation. The active path is context resolver → upload/controller → workbook preview/header mapper → per-sheet mapping → background job → workbook importer → athlete resolver/result writer → persisted rows and progress channel. A legacy row-based race resolver has no active callers and is excluded. All results use the batch-selected race.

| Capability | Decision | Reason / implementation contract |
| --- | --- | --- |
| Context → upload → preview → mapping → queue → progress → results | Retain | Full server-rendered wizard; event/race created transactionally |
| XLSX and all worksheets, header candidates, samples, letters beyond Z, unnamed columns | Retain and harden | Human confirmation/correction of headers; alias evidence beats densest-row guess |
| 17 destinations plus Unused, explicit aliases, duplicate/prerequisite guards | Retain and harden | Per-sheet UI and strict server validation reject crafted indexes and destinations |
| Passport | Retain internally, test only | Source service supports it; original dropdown does not. Public dropdown remains 17 fields |
| Typed cells, dates, time fractions/seconds/durations and status aliases | Retain and harden | Invalid supplied values fail explicitly; original display text remains separate |
| Result, registration, profile, unsupported and blank classification | Retain | Registration/profile rows create no results; blank rows now persist as skipped for truthful counters |
| Raw and mapped provenance | Retain and improve | Sheet, row, column letter/header, original type/value and normalized values retained separately |
| ID → passport → name/birth identity precedence | Retain and harden | Original tolerates conflicting names by ID; demo rejects material name/birth/identifier conflicts |
| Fill missing only, permanent number as attribute, club memberships | Retain | Permanent number is not an identity key; normalized club and membership uniqueness enforced |
| Ambiguous name-only identities | Harden | Batch-local identity without DOB/strong ID; later batches reject ambiguous matches rather than guessing |
| Race-number upsert across batches | Retain and harden | Preserve first creating batch; reject race number reassignment to another athlete |
| No race number | Retain | Match batch/race/athlete only; separate results across batches |
| Time display/seconds, positions, category and age at event | Retain | Event date and birth date determine age |
| Per-row transactions and partial success | Retain | Earlier committed rows survive failed rows; failure provenance persists outside rolled-back work |
| Background claim and replay | Harden | PostgreSQL advisory ownership, persisted claim token, terminal-row checkpoints and explicit resume; no exactly-once claim |
| Unique-conflict retries | Harden | Whole row retries outside rolled-back savepoint, verified with competing PostgreSQL sessions |
| Upload/archive limits; malformed/formula/external-reference handling | Harden | Bounded archive inspection before Roo; reject formulas and external references without fetching/executing |
| Authentication, authorization, CSRF, websocket ownership | Retain and harden | Rails password/session auth, owner-only batches/uploads/channels; default storage routes disabled |
| Audit uploader, history/search/pagination, details/errors | Retain | PaperTrail attribution and escaped server/DOM output |
| Original branding, source spreadsheets, unrelated APIs/CMS/deployment | Exclude | Fresh fictional domain and fixtures only; no production integrations |

Implementation is on the feature branch. See evidence.md for verification results and limits; the public main branch remains the minimal scaffold pending review.
