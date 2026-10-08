# Scoped formatter tool

This page is the repository-facing maintenance and verification entrypoint for the installed formatter helper. The portable contract shipped with the Skill is the authoritative runtime guide: [formatter tool reference](../skills/team-core/references/formatter-tool.md). The helper and its worker are under `skills/team-core/scripts/`.

The helper is part of the shared [code-readability contract](../skills/team-core/references/code-readability.md) and is routed by [`team-code-maintain`](../skills/team-code-maintain/SKILL.md). Keep the installed reference self-contained: it must not rely on repository-only `docs/` files, because installation distributes the Skill tree rather than this folder.

## Verification and maintenance

The active acceptance packet is [formatter-tool verification](verification/active/formatter-tool.md). It records focused cases for scope validation, formatter/config selection, trust and write boundaries, output/status behavior, and encoding/failure cases. The implementation tests are in `tests/test-formatter-tool.ps1`; package, installation and public-document checks remain separate validation layers.

When the runtime contract changes, update the portable Skill reference and this navigation page only as needed. Keep the verification packet aligned with the actual interface, and do not describe planned or blocked manual acceptance as completed. A successful formatter check is not a semantic test, an OS sandbox, or proof that formatting preserved behavior; review the diff and run the task's proportionate checks.
