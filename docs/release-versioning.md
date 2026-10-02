# Release versioning

This kit uses semantic version syntax, but release-number decisions follow the product policy below.

## Third number: focused extensions and fixes

Increment the third number for fixes, documentation, tooling, and additions that extend an existing feature without introducing a major new capability. Example: `0.3.0` to `0.3.1` for adding stage-level test and acceptance support to the existing workflow harness.

## Second number: major capability or broad workflow change

Increment the second number for a large new feature or a substantial restructuring of existing behavior. Examples include a new durable workflow family, a materially different execution model, or an extensive compatibility-affecting redesign.

## First number: explicit product-release decision

Increment the first number only when the maintainer explicitly declares a formal stable release or intentionally begins a new major product line. Do not promote the first number merely because several small changes have accumulated. Planned prerelease work uses the intended line with a suffix such as `1.1.0-alpha.1` or `1.1.0-beta.1` after that decision.

## Public documentation language pairs

The root `README.md` is the default English entrypoint; `README.zh-CN.md` is its Simplified Chinese counterpart. `CHANGELOG.md` and `CHANGELOG.zh-CN.md` carry the same release history. Keep both language pairs synchronized in the same change whenever factual setup, commands, models, supported capabilities, limitations or release information change. Technical code, paths, flags, model names and reasoning-effort values must match exactly; Chinese prose should convey the same meaning naturally rather than follow the English word for word. Preserve matching release versions, dates, categories and item counts, including historical entries.

For a content change to either language, run `scripts/validate-docs.ps1 -ProjectRoot .` and `tests/test-bilingual-docs.ps1`. These repository-only checks detect structural and technical drift; they do not validate translation meaning. Review the complete pair independently before handoff. This requirement applies to this repository's two public document pairs, not to every project or every document. Do not put machine-specific absolute paths in public content.

## Before releasing

1. State the intended version and why its number changes at that level.
2. Update `VERSION`, both changelogs, and the current-release reference in both READMEs together; keep both languages synchronized even when retaining the existing version.
3. Run `scripts/validate-docs.ps1 -ProjectRoot .`, `tests/test-bilingual-docs.ps1`, package validation and the relevant isolated tests.
4. Update the local installed kit only after the source checks pass.
5. Commit and push only the verified source state.
