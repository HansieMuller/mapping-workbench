# MappingWorkbench

Spreadsheet imports become difficult when one workbook mixes results, registrations and athlete profiles, and later uploads must update relational records without losing provenance.

MappingWorkbench is a standalone Rails demonstration of that engineering problem, using generated fictional data. This initial `main` scaffold boots locally; the complete importer is delivered in a separate review PR.

## Local scaffold

Ruby 4.0.7, Rails 8.1.4, local PostgreSQL, Redis. Install Ruby, then:

```sh
bundle install
bin/rails db:prepare
bin/rails server -b 127.0.0.1
bin/ci
```

No external accounts are needed. Database names are dedicated to this demo. Do not set `DATABASE_URL` to any existing system.

## Scope and provenance

The implementation is an authorized derivative of an existing importer, rebuilt in fresh history. No private repository links, source fixtures, customer records, credentials or deployment settings are included. Licensing of the derivative has not been independently established; no redistribution license is asserted here. Third-party packages retain their own licenses.

See [the parity checklist](docs/parity.md). This is a local portfolio demo, with no production-readiness claim.

Built with Rails; Codex assisted implementation and verification.
