# Bilingual public documentation readiness

## Scope and evidence

Scope: add synchronized English and Simplified Chinese public documentation. The current README and complete changelog pairs, repository instructions, folder guide, release policy, architecture boundary, stage packet, and shared documentation-governance contract were inspected. The first read-only governance Scan returned 18 indexed documents; a follow-up after the bilingual stage packet returned 19; the current Scan after adding `AGENTS.md` returned 20 documents (policy version 1, docsRoot `docs`). It reports the newly added root instruction file and the expected edits to the release policy, packet and English README. Root Chinese README/changelog and other non-default-root content are separately included as explicit dependencies.

No applicable product PRD or OpenSpec opt-in governs this maintenance task. The user's approval, the Lead's bounded parser/interface decisions, and the packet's BD-01 through BD-06 cases are the confirmed task requirements. Other active verification records and dated design/plan documents are classified as outside this scope; their semantic contents are not re-certified and they remain untouched.

## Sufficient information

The scope and source-of-truth assignments are clear: English remains the default public entrypoint; root `README.zh-CN.md` and `CHANGELOG.zh-CN.md` carry complete idiomatic Simplified Chinese equivalents; navigation is reciprocal; factual changes are synchronized in the same change; code, commands, model names, paths, flags, and reasoning-effort tokens retain exact technical values. Historical release headings, dates, categories and item counts correspond without rewriting repository history. README validation commands distinguish the package test's isolated temporary directories from the separate read-only documentation validator.

The structural checker is a separate repository-only `scripts/validate-docs.ps1` with isolated `tests/test-bilingual-docs.ps1`; it does not become part of package/install validation. Final source validator and focused drift suite passed; the packet also records passing native validation, selective package validation and fake-home installation tests with their owned fixtures removed. The checker verifies structure and technical parity signals, not whether Chinese prose is a correct semantic translation. The packet's human semantic/navigation checks and future-agent compliance remain manual pending. No exact machine-specific path appears in the owned public files.

The approved `0.9.3` source version is retained. This documentation/tooling extension fits a focused third-version increment and has not promoted the release to stable. The folder-guide archive statement was corrected because `docs/governance/reviews/archive/` exists; no archive move was performed. No actual local installation, commit or push occurred.

## Actual role roster and status

- `/root/bilingual_docs` — selected `team-docs-maintainer`; completed assigned translation and repository-documentation work.
- `/root/bilingual_validator` — selected `team-backend-engineer`; implemented the separate repository-only validator.
- `/root/bilingual_tester` — selected `team-tester`; authored the packet, isolated regression suite, and selective package-fixture correction; final test runs passed and owned temporary fixtures were removed.
- `/root/bilingual_reviewer` — selected `team-reviewer`; independent final review completed with no remaining material findings; final native/doc/packet checks and isolated bilingual/package suites passed, and owned fixtures were removed.

The exact named-role selectors were selected and source profiles were checked. Runtime identity/model for each selected role remains unknown. No role-creation failures, retries, or child recursion were recorded.

## Readiness and limits

No unresolved intent or authority ambiguity blocks the assigned implementation scope. Requirements, module boundary, checker contract, runtime instructions, isolated test expectations, and public-repository privacy constraints are specified. Structural tests and Markdown-link checks verify mechanical consistency. They cannot certify translation meaning, reader quality, completeness of an interpretation, future agent compliance, or rendered repository-host navigation. The Lead inspected the actual final source, test evidence, comment checks and independent Reviewer verdict, and authorizes closure of this bounded implementation. Final scoped RecordReview/Validate will bind these inspected inputs, not certify whole-project correctness. Human semantic/readability/navigation acceptance remains pending the user.
