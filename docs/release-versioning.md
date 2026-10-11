# Release versioning

This kit uses semantic version syntax, but release-number decisions follow the product policy below.

## Third number: focused extensions and fixes

Increment the third number for fixes, documentation, tooling, and additions that extend an existing feature without introducing a major new capability. Example: `0.3.0` to `0.3.1` for adding stage-level test and acceptance support to the existing workflow harness.

## Second number: major capability or broad workflow change

Increment the second number for a large new feature or a substantial restructuring of existing behavior. Examples include a new durable workflow family, a materially different execution model, or an extensive compatibility-affecting redesign.

## First number: explicit product-release decision

Increment the first number only when the maintainer explicitly declares a formal stable release or intentionally begins a new major product line. Do not promote the first number merely because several small changes have accumulated. Starting a major product line and declaring a stable release are separate decisions: `1.0.0` may still be an alpha, beta, or review preview and does not automatically mean stable. Planned prerelease work uses the intended line with a suffix such as `1.1.0-alpha.1` or `1.1.0-beta.1` after that decision.

## Public documentation language pairs

The root `README.md` is the default English entrypoint; `README.zh-CN.md` is its Simplified Chinese counterpart. `CHANGELOG.md` and `CHANGELOG.zh-CN.md` carry the same release history. Keep both language pairs synchronized in the same change whenever factual setup, commands, models, supported capabilities, limitations or release information change. Technical code, paths, flags, model names and reasoning-effort values must match exactly; Chinese prose should convey the same meaning naturally rather than follow the English word for word. Preserve matching release versions, dates, categories and item counts, including historical entries.

For a content change to either language, run `scripts/validate-docs.ps1 -ProjectRoot .` and `tests/test-bilingual-docs.ps1`. These repository-only checks detect structural and technical drift; they do not validate translation meaning. Follow the root `AGENTS.md` rule for semantic review of both languages and bounded reuse of a reachable prior complete review. This requirement applies to this repository's two public document pairs, not to every project or every document. Do not put machine-specific absolute paths in public content.

## Release preparation versus execution

Updating already confirmed version/date/release notes is metadata preparation, not permission to publish a release, tag, merge or install. Classify its execution under the shared [risk-proportional execution contract](../skills/team-core/references/execution-contract.md). Factual metadata-only preparation can be Lead-owned with explicitly non-independent self-checks. A small diff that changes harness behavior, permissions or another material boundary is not metadata-only work.

Choose verification from the changed inputs and applicable due gate. For metadata-only preparation, run the paired-document checks above, check version/date/item alignment and outgoing scope, and run package validation once on the intended source. Do not run the package-validator regression suite, installation/deployment tests, or unrelated feature suites merely because the version or changelog changed. Run those relevant isolated suites when their implementation, assertions, dependencies or risk changed. Reuse only trustworthy reachable evidence with relevant input identity; invalidate affected evidence and honor any gate requiring a fresh result. A later delivery step can reuse valid checks rather than repeating them automatically, but still checks its own current index/history/target scope.

## Before releasing

1. State the intended version and why its number changes at that level.
2. Update `VERSION`, both changelogs, and the current-release reference in both READMEs together; keep both languages synchronized even when retaining the existing version.
3. Run the paired-document checks and package validation, plus isolated tests selected under the input/risk rule above. Report executed and reused evidence separately; do not claim absent CI, runtime or manual acceptance passed.
4. Only on a separate direct install/update request, preview and update the local installed kit after source checks pass, following the installation and safe-deployment guides.
5. Commit and push only when authorized and only from the verified source state. Release publication, tags and merging require their own authority; release preparation does not imply them.
