# Upstream notes

This repository is its own source of truth. The following projects informed its design:

| Source | What was learned | Runtime dependency |
|---|---|---|
| ECC | Separate reusable Skills from role instructions; use focused frontend, backend, security, and testing guidance. | None |
| wshobson/agents | Keep capabilities modular, validate distributable artifacts, and map command-like workflows to Codex Skills. | None |
| OpenAI Codex documentation | Use `~/.codex/agents` for personal TOML agents and `~/.agents/skills` for personal Skills. | Codex itself |
| [OpenSpec 1.13.2](https://github.com/Fission-AI/OpenSpec/tree/v1.13.2) | Native current/delta specifications and archive lifecycle, consumed through a pinned CLI. Adapter and configuration template are independently authored; no upstream code or Skills are bundled. | Optional, explicitly installed OpenSpec CLI (MIT upstream) |
| [Anthropic frontend-design](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md) | Use a subject-appropriate visual baseline and inspect rendered results rather than rely on generic templates. | None |
| [Vercel Web Interface Guidelines](https://vercel.com/design/guidelines) | Treat layout, feedback, keyboard access and responsive behavior as concrete interface checks. | None |
| [Impeccable 4.6.0](https://github.com/pbakaus/impeccable/tree/6af45ac9a5eb8792f033d3242f52e99812fd91fa) | Selected Skill, shape, routing and distill guidance inform the adapted, conditional [usage guide](../skills/team-core/references/impeccable-usage.md); the adapter states when and how the user-installed capability is used. | Optional, separately installed Impeccable Skill for relevant assigned design/UI work; not a Kit setup dependency. |

The 0.6.0 UI guidance is independently written for this kit's page-level delegation and verification contracts. These references informed the design discussion; no upstream Skill source or external runtime dependency is bundled.

The 1.0.1 risk-proportional design-exploration contract is independently authored from the approved product requirements and this kit's existing Team contracts. No external brainstorming Skill text, code, or runtime is copied or bundled, and no upstream source or dependency is added for this capability.

The Impeccable guide is adapted from the pinned upstream Skill and the web references `.agents/skills/impeccable/SKILL.md`, `.agents/skills/impeccable/reference/shape.md`, `.agents/skills/impeccable/reference/routing.md`, and `.agents/skills/impeccable/reference/distill.md` at revision `6af45ac9a5eb8792f033d3242f52e99812fd91fa`. The guide is modified for this Kit's routing, authorization, ownership and evidence contracts. Its accompanying [license and attribution notice](../skills/team-core/references/licenses/impeccable-NOTICE.md) preserve the applicable Apache-2.0 terms. The upstream Skill, runtime, native-platform references and unrelated upstream notice material are not bundled.

ECC is MIT-licensed. This first version contains independently written, condensed guidance inspired by its public capability areas; it does not copy ECC Skill files. Any future direct import must record the source path, revision, license text, and attribution in this document and `NOTICE.md`.
