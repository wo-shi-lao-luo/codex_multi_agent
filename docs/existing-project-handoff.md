# 已有项目 Agent 接入入口

将以下内容交给正在开发业务项目的 Agent：

> 请依据本机已安装的 Codex Multi-Agent Kit，为当前项目补齐项目蓝图、阶段结构对齐与测试验收要求，并继续当前已授权的开发任务。请直接读取下列文件中的现行规则；已有代码重构的授权边界以这些规则及用户明确决定为准。
>
> 先读取当前项目适用的 `AGENTS.md` 和已有架构说明，再读取 Kit 的以下资源。下列路径以用户主目录为基准，不是当前业务项目目录。

| 资源 | 默认本机位置 |
| --- | --- |
| 开发总控 | `~/.agents/skills/team-dev/SKILL.md` |
| 规划 | `~/.agents/skills/team-plan/SKILL.md` |
| 共享规则入口 | `~/.agents/skills/team-core/SKILL.md` |
| 项目蓝图与已有项目接入契约 | `~/.agents/skills/team-core/references/project-blueprint.md` |
| 执行契约与任务模板 | `~/.agents/skills/team-core/references/execution-contract.md`、`execution-templates.md` |
| 角色路由与文件所有权 | `~/.agents/skills/team-core/references/role-routing.md`、`file-ownership.md` |
| TDD 与阶段验收 | `~/.agents/skills/team-core/references/tdd-protocol.md`、`test-acceptance-contract.md` |
| 测试与审查 | `~/.agents/skills/testing-engineering/SKILL.md`、`~/.agents/skills/team-review/SKILL.md` |
| 相关领域规则 | `~/.agents/skills/frontend-engineering/SKILL.md`、`backend-engineering/SKILL.md`、`database-engineering/SKILL.md`，按实际任务选择；后两者同属 `~/.agents/skills/` |
| 原生角色定义 | `~/.codex/agents/team-explorer.toml`、`team-architect.toml` 及任务相关角色文件 |
| 蓝图与阶段验证工具 | `~/.agents/skills/team-core/scripts/project-blueprint.ps1`、`stage-verification.ps1` |

同一行省略前缀的文件位于该行已注明的同一目录，领域 Skill 除外，其完整目录规则已在该行注明。PowerShell 中用户主目录使用 `$HOME`。

自定义安装位置以安装回执中的 `agentsHome` 和 `codexHome` 为准；默认回执位于 `~/.agents/codex-multi-agent/install-receipt.json`。本指南对应 `0.5.0` 的蓝图能力。若资源缺失或版本较旧，报告具体缺口，不要假设新规则已加载。

此文件是读取索引；实际行为以所列 Skill、契约、角色定义和脚本为准。
