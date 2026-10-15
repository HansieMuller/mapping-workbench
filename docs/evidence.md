# Verification evidence

Verification date: 2026-10-15. The final local command is `MW_DATABASE_PORT=5547 MW_DATABASE_USER=postgres bin/ci`. Intermediate failures were investigated and corrected; no assertions were removed to hide them.

## Final local results

| Check | Actual result |
| --- | --- |
| PostgreSQL Rails tests, including separate-session races | 47 runs, 425 assertions, 0 failures, 0 errors, 0 skips |
| Chrome / real Redis, Sidekiq and ActionCable system flows | 3 runs, 41 assertions, 0 failures, 0 errors, 0 skips |
| `zeitwerk:check` | All application constants autoloaded |
| RuboCop | 79 files, 0 offenses |
| Brakeman 8.1.0 | 0 errors, 0 security warnings |
| bundler-audit | No known gem vulnerabilities found |
| Importmap audit | No vulnerable JavaScript packages found |
| Publication audit | Intended files, workbook XML and every fresh historic blob passed |
| Gitleaks 8.30.1 | No leaks found in full fresh history or clean intended-file export, including archives |
| Reset smoke check | Old attached source and import data removed; fresh seed and private password recreated |

Hosted verification runs the same `bin/ci` command on the review PR. The PR's Checks tab and [workflow runs](https://github.com/HansieMuller/mapping-workbench/actions/workflows/ci.yml) retain the actual hosted outcomes and downloadable browser evidence. Do not treat a local pass as a hosted pass.

The [complete hosted campaign](https://github.com/HansieMuller/mapping-workbench/actions/runs/38730881032) passed for implementation commit `7dac0e2`: 47 PostgreSQL tests / 425 assertions and 3 Chrome tests / 41 assertions, with zero failures, errors or skips. Autoloading, 79-file RuboCop, Brakeman, both dependency audits and publication checks also passed. The [initial main scaffold campaign](https://github.com/HansieMuller/mapping-workbench/actions/runs/38722229732) separately passed. The PR remains open; its latest Checks tab verifies subsequent documentation-only commits.

Genuine screenshots from the synthetic system-test context: [mapping](screenshots/mapping.png), [outcomes](screenshots/outcomes.png), [results](screenshots/results.png), and [mobile history](screenshots/mobile-history.png). Each was visually reviewed before publication.

## Reproducible environment

The campaign uses Ruby 4.0.7, Rails 8.1.4, PostgreSQL 17.11, Redis 7.2.13, Sidekiq 8.1.7 and Chrome. Versions were checked against [Ruby's stable downloads](https://www.ruby-lang.org/en/downloads/), [Rails' published gem](https://rubygems.org/gems/rails/versions/8.1.4), [PostgreSQL's supported releases](https://www.postgresql.org/support/versioning/), [Redis' release](https://github.com/redis/redis/releases/tag/7.2.13) and [Sidekiq's published gem](https://rubygems.org/gems/sidekiq/versions/8.1.7). Exact gems and transitive dependencies are in the fresh `Gemfile.lock`; Compose pins both services.

## Evidence boundaries

A browser-harness issue was traced with Redis MONITOR: Turbo lazily installs ActionCable's in-process test adapter after Cable first loads. The second browser test was receiving direct snapshots while missing real Redis publications. The system harness now preserves the real Redis adapter after framework setup and asserts it for each case. The application was not given a polling shortcut to hide that failure.

The [first hosted full-importer run](https://github.com/HansieMuller/mapping-workbench/actions/runs/38729927130) failed because Rails automatically seeded a newly prepared test database. The demo operator then collided with the test-created operator. Demo seeds now skip the test environment, with a regression that failed before the fix and passes after it. The final local campaign above was rerun after dropping and recreating only `mapping_workbench_test`, so it exercises fresh-database preparation as well as the full importer. Development seeding/reset remains unchanged.

The [next hosted run](https://github.com/HansieMuller/mapping-workbench/actions/runs/38730412569) passed all 47 PostgreSQL tests, then exposed a missing screenshot output directory in a clean checkout. The system runner now creates that directory before the first native Chrome capture. The full local command was rerun with prior screenshot output moved aside; all three browser flows passed with fresh evidence. Assertions were retained.

Independent review also drove regressions for worksheet relationship/ID bypasses, Roo regex and suffix-shadowed archive parts, typed Excel durations beyond 24 hours, malformed wizard parameter shapes, header correction retaining unsaved mappings on other sheets, PostgreSQL position overflow, lost database-session ownership, stale/reconnected progress screens and leap-day birthday parity.

The fixtures are freshly generated fictional workbooks. The system campaign uses real Chrome, PostgreSQL, Redis, a separately spawned open-source Sidekiq process, authenticated sessions, CSRF-protected forms and ActionCable connections. It does not substitute `perform_now` for the browser's worker path.

The PostgreSQL campaign includes independent competing connections, a real unique insert collision/rolled-back savepoint, overlapping job ownership, concurrent identity/membership creation, and terminating only a test worker's backend before replacement ownership. Unit service tests separately cover interrupted processing/checkpoint replay, conflicts, fill-missing-only and result key parity.

Publication checks inspect tracked/intended files, generated XLSX XML, genuine screenshots and complete fresh Git history. Gitleaks 8.30.1 separately scans every fresh commit and a clean export of intended files with archive traversal. Logs, storage, local passwords and temporary evidence remain ignored. Pattern scans supplement manual review; they cannot prove the absence of every possible secret or undiscovered defect.

The reset smoke check first imported `mixed.xlsx` into the dedicated development database: 10 row outcomes, 4 results and 19 audit versions, plus an attached source file. After `bin/reset --confirm`, readback found no batches, rows, results, blobs or queued imports, and the old source file no longer existed. The fresh seed recreated one operator, event and race, two new audit versions, and a mode-0600 password file. This caught and corrected Active Storage's refusal to purge attached blobs; reset now purges attachments before orphan blobs.

The original importer was inspected on its actual default branch. No changes were made to the original repository; the build used a scratch inspection checkout, fresh Rails generation and new fictional fixtures. Private source URLs, excerpts and original public spreadsheets/lockfiles are excluded from public documentation.

## Remaining limitations

- Manual resume repairs interrupted/lost-delivery work. Open-source Sidekiq is not exactly-once execution; there is no transactional outbox or automatic recovery watchdog.
- Identity resolution takes a short global transaction lock. This favors defensible matching in a small demo over parallel throughput.
- Workbook parsing is bounded and tested, but is not a formal parser sandbox. Formulas, macros, external references, 1904 dates and noncanonical archive parts are deliberately unsupported.
- Raw unused columns are retained locally. Use fictional input and reset to remove it.
- Public deployment and scale are untested. Browser evidence is Chrome only; load tests and cross-browser campaigns were not run.
- Source investigation could not use the JetBrains backend because its IDE service was unavailable; the source Ruby version was also absent for LSP. Targeted call tracing was used there. LSP symbol lookup worked in the new application.
- No new redistribution license or exclusive-authorship claim is made. This authorized derivative stays open for independent review without merge or deployment.
