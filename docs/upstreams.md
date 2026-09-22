# Upstream notes

This repository is its own source of truth. The following projects informed its design:

| Source | What was learned | Runtime dependency |
|---|---|---|
| ECC | Separate reusable Skills from role instructions; use focused frontend, backend, security, and testing guidance. | None |
| wshobson/agents | Keep capabilities modular, validate distributable artifacts, and map command-like workflows to Codex Skills. | None |
| OpenAI Codex documentation | Use `~/.codex/agents` for personal TOML agents and `~/.agents/skills` for personal Skills. | Codex itself |
| [Anthropic frontend-design](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md) | Use a subject-appropriate visual baseline and inspect rendered results rather than rely on generic templates. | None |
| [Vercel Web Interface Guidelines](https://vercel.com/design/guidelines) | Treat layout, feedback, keyboard access and responsive behavior as concrete interface checks. | None |

The 0.6.0 UI guidance is independently written for this kit's page-level delegation and verification contracts. These references informed the design discussion; no upstream Skill source or external runtime dependency is bundled.

ECC is MIT-licensed. This first version contains independently written, condensed guidance inspired by its public capability areas; it does not copy ECC Skill files. Any future direct import must record the source path, revision, license text, and attribution in this document and `NOTICE.md`.
