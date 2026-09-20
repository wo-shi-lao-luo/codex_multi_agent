# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-09-20

### Added

- A framework-neutral TDD protocol with `test-first`, documented `test-after`, and `manual-or-environmental` tracks.
- Packet validation that checks controlled coverage decisions, TDD evidence, a unique final manual status, and safe archival conditions.
- Isolated tests for stage-packet validation, state handling, archival, and test cleanup.

### Changed

- `$team-dev`, `$team-plan`, `$team-debug`, `$team-review`, and `testing-engineering` now use the shared TDD protocol at their relevant lifecycle points.

## [0.3.1] - 2026-09-20

### Added

- Git-tracked stage verification packets with use cases, coverage decisions, automated plans, and human verification scripts.

### Changed

- `$team-dev` establishes and reconciles a Test & Acceptance Contract before and after implementation.

## [0.3.0] - 2026-09-18

### Added

- Local, opt-in-by-workflow acceptance records for the four explicit `team-*` workflows.
- A `team-core` feedback runtime that validates run records, aggregates candidate signals, archives aged records, and requires explicit confirmation before deletion.
- Isolated runtime tests and an approved feedback-loop architecture design.

### Changed

- The installer now ships the feedback runtime as part of the existing `team-core` Skill package.

## [0.2.0] - 2026-09-18

### Added

- Safe user installation, update, validation, receipts, backups, and isolated package tests.
- Model routing for the seven team roles.

### Changed

- Standardized all executable Skills on the shared team execution harness.

## [0.1.0] - 2026-09-18

### Added

- Initial Codex multi-agent team, explicit workflow Skills, and shared execution contracts.
