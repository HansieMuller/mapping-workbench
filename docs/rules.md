# Mapping, normalization and reconciliation rules

## Mapping

Each worksheet has an independently confirmed header row and index-to-destination map. Header suggestions use normalized explicit aliases; ambiguous short words such as Name, ID, Time and unknown/internal fields stay Unused. Original headers, unnamed columns and Excel letters beyond Z survive. Branded source aliases were generalized/excluded rather than publishing branding.

The 17 destinations are race number, first name, last name, full name, ID number, permanent number, date of birth, gender, email, mobile number, club, finish status, finish time, overall position, category, category position and gender position. Passport remains service-level support with tests; it is not an original or public dropdown destination.

The UI disables duplicate destinations within one sheet and reports missing prerequisites. Server validation is authoritative: reject non-object maps, unknown sheets, missing/crafted indexes, unsupported destinations and duplicate fields. Header correction carries unsaved choices into a structurally validated draft, preserves sheets whose header row is unchanged and resets suggestions only on corrected sheets. Final result prerequisites are deferred for that draft and enforced before queuing: at least one sheet must map finish time, and sheets mapping finish time or finish status must map ID number, full name, or both first/last names. The finish-status-only prerequisite is an additional defensive guard. Headers/mappings become immutable when queued.

## Typed values and classification

Original raw values, Roo type, interpreted value, column index/letter/header, source sheet and row are stored separately from mapped normalized values. Unused columns are retained. Numeric identifier cells cannot recover lost leading zeroes: store synthetic IDs as text in Excel.

Date objects, positive whole Excel 1900 date serials, YYYY-MM-DD, YYYY/MM/DD, DD/MM/YYYY and compact YYMMDD are supported. Compact birth dates choose the century relative to the selected event year. Invalid supplied dates and future birth dates fail explicitly. The 1904 workbook date system is rejected. Strict input formats prevent locale-dependent guesses.

Unformatted positive numbers below one are Excel day fractions; numbers at least one are seconds, following the source contract. Duration text is HH:MM[:SS[.fraction]] and decimal seconds round to a whole second. Minutes/seconds must be below 60, and total duration must be below 200000 seconds. Typed Excel duration/time cells preserve elapsed days: 1.25 days in `[h]:mm:ss` becomes 30:00:00 / 108000 seconds. Calendar date-time cells are not accepted as an arbitrary race duration when outside the supported range.

Known aliases classify finished, DNS, DNF, disqualified and query results, including Not yet started, Withdrawn during race and Started and running. Original status text is retained. Unknown status or race number without a result produces registration; useful identity without result produces profile; other mapped content is unsupported; empty mapped values are blank. Registration/profile rows create athletes without inventing results. Blank/unsupported rows persist as skipped, including their provenance.

Positions must be positive whole integers within PostgreSQL's integer range. Age uses the selected event date and birth date, ignoring any spreadsheet age. For a February 29 birthday, the original calendar rule considers it passed on March 1 in a non-leap year.

## Identity

1. Match a syntactically valid 13-digit ID.
2. Match a passport (internal service capability).
3. Match normalized full name plus birth date only when exactly one compatible candidate exists.

IDs in examples deliberately begin with zeroes and are synthetic, not valid national identities. Placeholder IDs/names such as N/A and Unknown never become strong identity keys. Permanent number remains a fill-missing attribute, not an identity match key.

Conflicting strong IDs, passport, birth date or material normalized name fail the row. This hardens the source's willingness to accept a different name for an existing ID. Multiple name/birth candidates require a strong identifier; there is no silent merge. Strong identifiers cannot be reassigned through a name/birth fallback.

Name-only profiles without birth date or strong ID get a batch-local identity key. Repeated names in that batch reuse it. Later batches finding that name without adequate identity fail rather than creating another duplicate or guessing that it is the same person. Supply ID or birth date for safe cross-batch reconciliation.

Existing athlete fields are filled only when missing. Normalized club names prevent case/whitespace duplicates; athlete/club memberships are unique. Distinct athletes can legitimately share a name and birthday, so ambiguous matching must fail.

## Result upserts

With a race number, match `(selected race, race number)` across batches. The existing athlete must agree with identity resolution. Another athlete cannot take over the number. Preserve the result's creating batch and audit every contributing row.

Without a race number, match `(batch, selected race, athlete)`. Repeat rows in that batch reuse the result; a later batch intentionally creates its own unnumbered result.

A result update replaces the imported result payload. Omitted/unmapped time/status/position/category/gender/club fields become nil, matching the source behavior. Fill-missing-only applies to athlete profiles, not result attributes. Use a complete result mapping when correcting a numbered result if those attributes need retaining.

## Workbook safety contract

Server limits: 5 MiB uploaded, 30 MiB expanded archive, 100 entries, 8 sheets, 10000 rows per sheet, 20000 total worksheet rows, 128 columns, 200000 cells and 4096 bytes per cell/shared string. Declared dimensions and actual cell coordinates are checked before Roo allocates worksheet data.

Reject malformed archives/XML, traversal/symlink paths, entity declarations, formulas, binary/macro parts, external links/relationships and unsupported/nonexistent worksheet targets. Worksheet part basenames accept ASCII letters, digits, underscores and hyphens only, because Roo interprets target filenames through a regular expression. Every reader suffix match must identify a unique canonical worksheet or metadata part, so shadow files cannot substitute different content. Sheet IDs must agree with worksheet relationship IDs. The app never evaluates formulas or fetches external references; upload a plain values-only XLSX. These are bounded local-demo controls, not a hardened public upload service or formal parser sandbox.
