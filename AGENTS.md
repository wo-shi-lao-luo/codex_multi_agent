# Repository maintenance instructions

## Public documentation language pairs

- Keep `README.md` as the default English entrypoint and maintain its complete Simplified Chinese counterpart in `README.zh-CN.md`. Keep `CHANGELOG.md` and `CHANGELOG.zh-CN.md` synchronized across every release section.
- When either language changes a factual setup instruction, command, model assignment, supported capability, limitation, version, release date, or release item, update the counterpart in the same change. Preserve technical values such as code, paths, flags, model names and reasoning-effort values exactly; translate surrounding prose naturally rather than word for word.
- Keep reciprocal language-navigation links in both README files and both changelogs. Keep release headings, dates, categories and item counts aligned. Do not shorten or rewrite historical release records to make the pair easier to maintain.
- Run `scripts/validate-docs.ps1 -ProjectRoot .` and `tests/test-bilingual-docs.ps1` when changing either pair. These checks compare structure and technical signals; they do not establish that a translation preserves meaning. Review both complete documents for semantic accuracy, readability, equivalent caveats and navigation before handoff.
- This repository rule applies only to this repository's public README and changelog pairs. It does not require other projects or their documents to provide Chinese translations.
- Do not include personal machine-specific absolute paths in public repository documents. Use repository-relative paths or generic examples.

## Documentation placement

Keep root README files focused on stable orientation, setup, basic commands, user-relevant limitations and navigation. Put detailed procedures and task results in their existing authoritative documents under `docs/`. Follow `docs/release-versioning.md` for release numbering and coordinated public-document updates.

## User-level Codex installation

Opening this repository, asking about installation, or reviewing installation documentation does not authorize changes to a user's Codex homes. Proceed with a user-level install or update only on a direct user request to install or update this Kit, and follow `docs/codex-install.md` plus `docs/safe-deployment.md`. Preview the selected source and target first; stop on unexpected source state or conflicts that require a separate choice. Do not infer permission to edit global Codex configuration or to force-replace conflicting files. Do not claim that installed files prove the active Codex session loaded a Skill or agent.
