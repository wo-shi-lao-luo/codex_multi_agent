# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

