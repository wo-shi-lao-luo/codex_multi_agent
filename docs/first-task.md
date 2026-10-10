# Your first task / 首次任务

[English](#english) | [简体中文](#简体中文) | [Repository](../README.md)

## English

### Before you start

Use Codex on the computer where you want the Kit installed. Follow the [installation guide](codex-install.md), select the source you intend to try, and confirm that the required Skills and named agents are available in the new session. A copied file is not proof that Codex loaded it. Check model availability before starting; the Kit does not silently substitute models.

Use a disposable local project for this exercise. Installation is a separate explicit request; do not run the user installer merely to read this guide. This is a reproducible exercise, not a transcript or a claim that a live multi-agent run has already passed.

Team may be task-matched automatically for engineering work, but host selection is best effort. This exercise invokes `$team` explicitly so the entry remains clear when automatic matching does not occur.

### Copy this task into Codex

```text
$team Build a tiny Python temperature converter in this disposable project. Use only the Python standard library. Provide celsius_to_fahrenheit(value) and fahrenheit_to_celsius(value), with unittest coverage for freezing, boiling, negative values, and round-trip conversion using a float tolerance. Do not add a UI, network access, or dependencies. State the plan and actual role assignments, implement the functions, run the tests, review the result, and report changed files, executed checks, actual child-agent identities, and any unverified claims. Follow applicable project and Kit instructions; do not claim success if a required role or runtime capability is unavailable.
```

### Check the result

- The two functions exist and use the expected formulas: multiply Celsius by 9/5 and add 32; subtract 32 from Fahrenheit and multiply by 5/9.
- Tests cover 0°C → 32°F, 100°C → 212°F, −40°C → −40°F, both directions, and round trips with a float tolerance.
- Run `python -m unittest discover -v` in the example project. Read the actual output; a planned command does not count as a pass.
- The final report identifies who actually participated, what each role owned, the checks that ran, and what remains unverified. A role name written in a plan does not prove that a child agent ran.
- Review the diff yourself. The exercise checks a small development path; it does not establish performance, cost savings, or suitability for a production project.

If Codex cannot discover a required Skill or agent, stop the exercise and use the installation guide's discovery checks. Do not change your global configuration just to hide the failure.

### Compare with an observed run

A [maintainer-run temperature example](examples/temperature/README.md) includes the final source, tests and a redacted record of actual role calls, Red/Green and independent review. It is source-read workflow evidence; it does not prove a fresh installation or external adoption, and human acceptance remains pending.

### Tell us what happened

[Report an installation or first-task problem](https://github.com/wo-shi-lao-luo/codex_multi_agent/issues/new?template=first-use.yml), or [share a completed first task](https://github.com/wo-shi-lao-luo/codex_multi_agent/issues/new?template=usage-feedback.yml). Include the Kit source/version, Codex client, operating system, the step you reached, and a short redacted error or test summary. Never include credentials or private project files. Sharing feedback is optional; the Kit does not automatically send usage data through these forms.

## 简体中文

### 开始前

在希望安装工具包的电脑上使用 Codex。按[安装指南](codex-install.md)选择要试用的源码，并在新会话中确认所需 Skills 和具名智能体可用。文件已复制不代表 Codex 已加载。开始前确认模型可用；工具包不会静默替换模型。

请在一个可丢弃的本地项目中练习。安装需要单独明确提出；阅读本指南不需要运行用户级安装器。以下是可复现的练习，不是运行实录，也不表示真实多智能体流程已经通过。

工程任务可能被自动匹配到 Team，但是否选中取决于宿主。本练习显式调用 `$team`，即使没有自动匹配也能按示例操作。

### 复制上面的任务到 Codex

英文任务以 `$team` 显式启动，要求仅用 Python 标准库实现摄氏与华氏温度互转，提供两个函数，使用 unittest 检查冰点、沸点、负数和带浮点容差的往返转换。不要添加界面、联网功能或依赖。要求 Codex 说明计划和实际分工，完成实现、测试与审查，并汇报修改文件、已执行检查、实际子智能体身份和尚未验证的事项。缺少必需角色或运行能力时不能声称成功。

### 检查结果

- 两个函数使用正确公式：摄氏温度乘以 9/5 后加 32；华氏温度减去 32 后乘以 5/9。
- 测试包含 0°C → 32°F、100°C → 212°F、−40°C → −40°F，覆盖双向转换及带浮点容差的往返转换。
- 在示例项目中运行 `python -m unittest discover -v`，查看真实输出；计划中的命令不能算通过。
- 最终报告说明实际参与者、各自职责、已执行检查和尚未验证的部分。计划里写了角色名称，不能证明子智能体实际运行过。
- 自己检查修改差异。练习只验证一条小型开发路径，不能证明性能、成本节省或生产项目适用性。

如果 Codex 无法发现所需 Skill 或智能体，停止练习，按安装指南检查发现状态。不要为了掩盖失败而修改全局配置。

### 对照一次实际运行

[维护者运行的温度转换示例](examples/temperature/README.md)提供最终源码、测试，以及实际角色调用、Red/Green 和独立审查的脱敏记录。这份证据来自直接读取源码规则的工作流运行，不代表已验证全新安装或外部用户采用；人工验收仍待确认。

### 反馈使用情况

可以[反馈安装或首次任务问题](https://github.com/wo-shi-lao-luo/codex_multi_agent/issues/new?template=first-use.yml)，也可以[分享已完成的首次任务](https://github.com/wo-shi-lao-luo/codex_multi_agent/issues/new?template=usage-feedback.yml)。请说明工具包源码或版本、Codex 客户端、操作系统、进行到哪一步，并附上简短的脱敏错误或测试摘要。不要包含凭据或私有项目文件。反馈完全自愿；这些表单不会自动发送使用数据。
