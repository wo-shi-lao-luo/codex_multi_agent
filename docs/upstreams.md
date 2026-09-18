# Upstream notes

This repository is its own source of truth. The following projects informed its design:

| Source | What was learned | Runtime dependency |
|---|---|---|
| ECC | Separate reusable Skills from role instructions; use focused frontend, backend, security, and testing guidance. | None |
| wshobson/agents | Keep capabilities modular, validate distributable artifacts, and map command-like workflows to Codex Skills. | None |
| OpenAI Codex documentation | Use `~/.codex/agents` for personal TOML agents and `~/.agents/skills` for personal Skills. | Codex itself |

ECC is MIT-licensed. This first version contains independently written, condensed guidance inspired by its public capability areas; it does not copy ECC Skill files. Any future direct import must record the source path, revision, license text, and attribution in this document and `NOTICE.md`.
