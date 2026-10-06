# Codex 多智能体工具包

[English](README.md) | 简体中文

面向 Codex 的轻量级个人开发团队。它使用 Codex 原生子智能体和 Skills；运行时不依赖 ECC、OMX、任务守护进程或其他智能体 harness。

## 工作流入口

- `$team-dev <goal>` — 规划、实现、测试、审查并汇报开发任务。
- `$team-plan <goal>` — 制定可供决策的计划，不编辑代码。
- `$team-review <scope>` — 并行审查分支、代码差异或变更集。
- `$team-debug <symptom>` — 先调查不确定的故障，再决定是否修改。
- `$team-ai-simulate <AI agent or workflow>` — 显式地在本地模拟有界的 AI 行为，再决定是否工程化。
- `$team-doc-check <task>` — 采用或重新检查项目文档，并生成针对当前任务的就绪度评估。
- `$team-project-rules <task>` — 检查、起草或维护目标项目的 `AGENTS.md` 指引。

## 团队成员

`team-explorer`、`team-architect`、`team-ai-architect`、`team-docs-maintainer`、`team-frontend-engineer`、`team-backend-engineer`、`team-database-specialist`、`team-tester`、`team-reviewer`、`team-ai-simulation-actor-basic`、`team-ai-simulation-actor-advanced` 和 `team-ai-engineer` 是 Codex 自定义智能体。基础和高级模拟角色都只负责一个受限的行为节点，并遵守相同边界；`team-ai-architect` 负责提出 AI 领域设计方案，`team-ai-engineer` 实现分配给它的应用 AI 行为。主 Codex 对话负责 Lead 工作，持有任务状态、整合结果并给出最终答复。

## 模型分配

| 角色 | 模型 | 推理强度 |
| --- | --- | --- |
| 架构师 | `gpt-6.1-sol` | xhigh |
| 探索员 | `gpt-6-luna` | medium |
| 文档维护者 | `gpt-6-luna` | high |
| 前端、后端、测试 | `gpt-6.1-sol` | medium |
| 数据库专家、审查员 | `gpt-6.1-sol` | high |
| AI 模拟角色基础档 | `gpt-6-luna` | medium |
| AI 模拟角色高级档 | `gpt-6.1-sol` | medium |
| AI 架构师 | `gpt-6.1-sol` | xhigh |
| AI 工程师 | `gpt-6.1-sol` | medium |

主 Lead 建议使用 GPT-6 Astra / high。这是建议，不是已安装的智能体设置。可选配置片段将通用子智能体设为 GPT-6.1 Sol / medium；具名团队角色保留各自显式配置。已经合并旧配置片段的用户需要手动更新其中两个 `default_subagent_*` 值；安装器不会合并全局配置。

这些模型分配是工作负载选择，不代表经过测量的质量保证。请参阅官方[子智能体模型指南](https://learn.chatgpt.com/docs/agent-configuration/subagents)，并在目标账号和客户端中确认模型是否可用。

架构师使用 GPT-6.1 Sol / xhigh，为架构权衡投入更多推理；Astra Lead 会在实施前检查重要决策。推理强度更高并不代表效果等同于 Astra。请参阅[官方模型指南](https://developers.openai.com/api/docs/models/gpt-6.1-sol)，并用有代表性的项目评估遗漏、返工和完成时间。

本工具包没有自动模型回退机制。Git 历史中的旧模型分配可作为人工恢复时的参考，但不要同时启用第二套配置。如果模型不可用或出现可复现的退化，应先查明原因并确认替代模型可用，再进行范围明确的配置修改，同时更新对应的校验器并完成验证。不要静默切换模型，也不要假定旧模型能够绕过服务中断或账号限额。

## 为单个用户安装

在本仓库中使用 PowerShell 7：

```powershell
.\scripts\validate.ps1
.\scripts\install-user.ps1
```

从较新版本的工具包安全更新已有安装：

```powershell
.\scripts\update-user.ps1
```

`update-user.ps1` 与安装器使用相同的收据、`-WhatIf` 预览、冲突保护和 `-Force` 备份行为。它不会修改 `~/.codex/config.toml`。

安装、升级和降级由同一个部署管理器处理。目标版本不再包含、但由收据管理的组件会被移除，包括保留的 Skills 中已经过时的文件。遇到未知或已修改的内容时会阻止替换，除非显式使用 `-Force` 先备份。请参阅[安全部署与可复用回退](docs/safe-deployment.md)，了解如何在尝试新版本前固定经过测试的稳定快照、离线恢复，或在不改动当前检出版本的情况下部署本地 Git 提交。备份和恢复管理器有意放在 agent/Skill 发现路径之外；项目数据不会随工具包回退。

要在不改动实际 Codex 或 Skills 目录的情况下验证可分发的软件包，请运行：

```powershell
.\tests\test-validate.ps1
.\tests\test-stage-verification.ps1
.\tests\test-project-blueprint.ps1
.\tests\test-install-user.ps1
.\tests\test-deployment.ps1
.\tests\test-documentation.ps1
.\tests\test-feedback-runtime.ps1
.\tests\test-ai-simulation.ps1
```

这些测试只在唯一的系统临时目录中运行。它们会检查无效元数据和缺失的本地引用、TDD 阶段包的初始化与安全状态转换、完整软件包和更新行为、反馈运行时的校验/聚合/归档/删除确认/清理，以及本地 AI 模拟定义和运行证据处理；每个测试退出前都会移除自己的临时目录。

要单独检查公开文档的结构和同步情况，请运行：

```powershell
.\scripts\validate-docs.ps1 -ProjectRoot .
.\tests\test-bilingual-docs.ps1
```

安装器会把 agents 复制到 `~/.codex/agents`，把 Skills（包括内部 `team-core` 策略包和反馈运行时）复制到 `~/.agents/skills`。它不会覆盖或合并 `~/.codex/config.toml`。可选的 [`config/recommended-config.toml`](config/recommended-config.toml) 建议每个会话最多同时打开六个子线程，不计 Lead。如果之前合并过旧版本，请将 `max_concurrent_threads_per_session` 从 `3` 手动改为 `6`。当前 Codex 会话实际允许的上限可能更低；配置值不能证明设置已加载，也不能证明六个线程当前可用。

安装器写入前会先验证工具包。使用 `-WhatIf` 可预览操作。如果目标位置已有文件或 Skill 目录，且收据没有记录为未改动的安装内容，安装器就会停止；只有在确实希望备份并替换冲突内容时才使用 `-Force`。默认情况下，安装收据和备份保存在 `~/.agents/codex-multi-agent/`。

agent 名称使用 `team-` 前缀，以避免与个人 agent 重名。安装收据没有记录的历史组件会保留原样；手动删除前应先确认其归属。

当前版本: `1.0.1`（1.0 产品线的增量扩展；不代表宣告稳定版）。工具包自有的本地产物采用范围明确的 Git 保护，并检查实际索引。文档治理元数据、导航索引和审查记录保留在当前检出目录中，但不会通过 Git 共享；新检出的仓库需要根据现有文档自行建立采用及审查状态。用户编写的项目文档、PRD、蓝图、阶段验证包和原生规格仍可纳入版本控制。已跟踪的本地产物或与用户显式包含规则冲突的情况需要用户决定如何处理。工具包不会安装 Git hook 或后台监控，用户仍可手动强制暂存。详见[生成产物 Git 保护约定](skills/team-core/references/generated-artifacts.md)。反馈运行时目前支持 `$team-dev`、`$team-plan`、`$team-debug` 和 `$team-review`；`$team-ai-simulate` 使用单独的本地运行记录，不调用该运行时。`$team-dev` 会在目标项目中创建并校验由 Git 跟踪的阶段验证包；条件允许时使用 `test-first`，否则记录采用的替代路径。普通修复失败两次后，工作流会查找相关外部证据；适用的新证据最多可支持一次有条件的扩展，修复总次数不超过五次。Debug 模式的资料检索计入原有六轮诊断额度。暂停依据证据进行；恢复需要用户授权。正常推进的长时间操作按任务设置进度检查点，不设统一时间上限。测试执行采用风险分层和基于证据的结果复用；测试范围不清楚时可定向请 Explorer 查找，但 E2E/人工覆盖和仓库门禁仍具有约束力。请参阅[修复与诊断循环约定](skills/team-core/references/repair-loop-guard.md)、[反馈记录规则](skills/team-core/references/feedback-recording.md)、[测试与验收约定](skills/team-core/references/test-acceptance-contract.md)、[TDD 流程](skills/team-core/references/tdd-protocol.md)、[代码注释约定](skills/team-core/references/code-comments.md)、[项目指引约定](skills/team-core/references/project-rules.md)、[AI 模拟指南](docs/ai-simulation.md)、[版本规则](docs/release-versioning.md)和[更新日志](CHANGELOG.zh-CN.md)。0.1.0 版本还将 `sql-safety` 更名为 `database-engineering`，并将 `test-strategy` 更名为 `testing-engineering`。历史 Skill 目录如果未记录在安装收据中，会保持不变；由收据管理且已停用的 Skills 会与所选目标版本保持一致。

涉及可见界面的工作会将 [frontend-design](skills/frontend-design/SKILL.md) 与 frontend-engineering 配合使用。[UI 交付约定](skills/team-core/references/ui-quality.md)会保留页面级目标，明确完整页面或流程的负责人，并要求将渲染检查与功能测试分别留证。无需为此增加专门的设计智能体、改变模型或为每个页面单独编写设计文档。缺少浏览器证据时，必须注明尚未进行视觉验证，不能称为已可发布。

如果新安装的 Skill 没有立即显示，请重启 Codex。

## 工作约定

显式调用 `$team-dev` 进行代码修改时，包括小型修复和改变行为的脚本、配置或 Skill 指令，默认由具名实现者和 `team-tester` 配合完成。独立审查和专家角色由风险及影响决定，不以文件数或行数判断。小任务可以缩短记录，但仍需完成适用的工程检查。只有用户明确要求 Lead 亲自执行代码工作，或批准具体的 Lead 单独处理例外时，Lead 才会直接改代码；普通的“直接修一下”不等于这个授权。缺少角色时不能静默改由其他角色代替。请参阅[角色分配规则](skills/team-core/references/role-routing.md)和[最小完整流程](skills/team-core/references/execution-contract.md)。单纯拼写和格式调整等不改变行为的工作可以由 Lead 直接完成。任务开始和结束时都要把计划角色、检查项与实际证据对齐。这些内部规则不会让 Team 工作流在其显式入口之外自动启用。

`$team-plan` 和 `$team-dev` 会根据重要风险和未解决的不确定性选择轻量检查或更完整的设计探索，而不是按任务或文件规模判断；除非相关新证据改变了适用范围，已确认的决定不会重复进入审批。详见共享的[设计探索约定](skills/team-core/references/design-exploration.md)。

阶段测试计划遵循[人工到自动化的覆盖约定](skills/team-core/references/test-acceptance-contract.md#manual-scope-and-automated-coverage)：E2E 计划要包含每个人工场景或要求，并保留等价的条件、结果和检查点。遇到用户新增或修改的要求时，同步更新 E2E、适用的其他层测试、覆盖映射和相关证据。无法自动化的观察项仍要列出，并等待用户决定是否例外；写进计划不代表已经通过测试。不会增加后台监控，也不会自动改写已归档的验收记录。

[高效测试执行规则](skills/team-core/references/test-acceptance-contract.md#efficient-test-execution)默认适用于 Codex 执行的所有产品测试。优先使用可重复的程序化执行入口和结构化结果摘要；通过合适的 API/集成入口广泛覆盖业务规则，同时保留完整的浏览器用户流程及独立的 UI/客户端风险。只有在条件和断言等价且有证据支持时才合并重复断言；保留渲染视觉检查和人工验收。不强制新增 API、生产代码测试缝隙、每步截图流程，也不宣称已测得 token 节省。

### 文档就绪度

团队规划和开发流程遵循[文档治理约定](skills/team-core/references/documentation-governance.md)。已有项目会先按任务范围发现并采用现有文档；新增或修改的文档要分类，复用旧证据前要重新检查。docs/governance 标记表示项目已纳入治理跟踪，不代表整个项目的文档检查都已通过。优先使用 docs/，适用的活动 PRD 放在 docs/PRD，确认已被替代的材料放在 docs/legacy；不要求固定文档清单，也不创建空分类目录。是否就绪取决于任务所需信息，不取决于文件名。遇到意图不明确、权威来源冲突或归档状态不确定时，应先向用户说明，再开展依赖该决定的工作；明确独立的工作可以在部分就绪评估下继续。运行时哈希只能发现变化，不能证明语义充分或用户已批准。没有后台监控，也不会自动采用 OpenSpec。

`$team-plan` 和 `$team-dev` 会在任务开始、首次进入相关模块，以及相关规则、命令或约定依据发生变化时检查适用的项目指引。即使任务没有提到 `AGENTS.md`，Lead 也会把有证据且影响当前任务的缺口和建议改动告知用户；文件缺失、内容短或陈旧本身不会触发提议。修改任何目标项目指引文件都需要用户批准具体的路径和规则范围；普通开发授权不包含这项权限。复用已有决定记录，避免重复提出没有变化的建议。详见[项目指引约定](skills/team-core/references/project-rules.md)，其中说明根目录、嵌套目录、覆盖文件及范围限制。这些检查不增加后台监控，也不会自动修改文件。

### 可选的 OpenSpec 集成（审查预览）

工具包可以选择使用外部安装的 OpenSpec **1.13.2** 管理规格，同时保留自身的 Lead、TDD 和验收流程。工具包安装器不会安装或启用它。适配器需要 PowerShell 7 和上游 Node.js 20.19+；配置步骤、支持范围和恢复方式见[集成约定](skills/team-core/references/openspec-integration.md)。未设置启用标记的已有项目不会被修改。首个支持范围不包含自定义 schema 或存储方式。

运行 `tests/test-openspec.ps1` 可执行隔离的约定测试。传入 `-OpenSpecEntry <trusted-installation>/bin/openspec.js` 可增加真实的固定版本 CLI 流程测试；测试期间不会下载依赖。该能力的版本号是 0.7.0，但版本号不表示维护者已批准其稳定发布，也不会更新本地安装。

新应用、多阶段计划和重要结构调整使用 [Project Blueprint](skills/team-core/references/project-blueprint.md)。在记录模块和文件职责前，先了解已有仓库结构。结构性重构必须得到用户明确批准；如果用户拒绝或暂缓，就保留现有结构并记录约束。阶段包会记录 Blueprint 版本、模块 ID、文件范围和入口例外。Blueprint 校验检查文档结构，代码审查检查实际架构。

- 建议的上限是 Lead 整个会话中最多同时打开六个子线程，实际容量较低时以主机限制为准。通常 2–3 个就够；只有工作输入已就绪且彼此独立时才增加并发。超过三个前，先向用户说明原因，并在现有工作记录中写明各自的独立产出、依赖、写入边界和整合安排。详见[自适应并发规则](skills/team-core/references/role-routing.md#adaptive-child-thread-concurrency)。
- 默认由一个负责人编写生产代码。只有在文件或模块分工不重叠时，Lead 才使用 worktree。
- 只有输入已就绪且产出彼此独立的工作才适合并行，例如只读检查、负责不同文件或使用隔离测试夹具。共享可变测试状态和有依赖关系的工作应依次进行；修改共享约定前先确定方案。
- 角色应向 Lead 汇报发现、修改文件、验证结果和阻塞项；只有 Lead 负责宣布任务完成。
- Team 工作流会先对照当前工具目录检查所需具名角色，并显式选择角色；任务标签或源 TOML 不能证明角色或模型已实际加载。若角色不可用，应先向用户确认替代方案。最终答复要列出实际调用的子智能体（ID、所选角色、任务和状态），包括创建失败或重试；若没有调用，也要明确写出。无法确认的运行时身份或模型应标为未知。

更多内容请参阅[架构说明](docs/architecture.md)、[角色分配规则](skills/team-core/references/role-routing.md)和[上游来源说明](docs/upstreams.md)。
