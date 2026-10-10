# Temperature conversion: a maintainer-run example

[简体中文](#简体中文) | [First-task guide](../../first-task.md) | [Run evidence](evidence/run.md)

This is the result of a real, small development exercise using native Codex child
agents. A backend owner implemented the functions, a separate Tester wrote and ran
the tests, and an independent Reviewer inspected the code and execution evidence.
The workflow instructions were read from the Kit's 1.0.7 source. This does not prove
that a fresh installation discovered the Skills or that an external user adopted the Kit.

Copy this directory into a disposable local project, then run:

```sh
python -B -m unittest discover -v
```

The example uses only Python's standard library. Its observed run used Python 3.12.14.
Four test methods cover 22 reference, fractional and round-trip scenarios. The
[run record](evidence/run.md) distinguishes the observed Red, Green and review from
unverified installation, human acceptance, model identity and performance claims.

```python
from temperature import celsius_to_fahrenheit, fahrenheit_to_celsius

print(celsius_to_fahrenheit(0))    # 32.0
print(fahrenheit_to_celsius(212))  # 100.0
```

Inputs exercised here are finite integer/float samples. Tests compare results with
absolute tolerance `1e-9`. No UI, CLI application, dependencies, network calls,
physical-range validation or invalid/extreme-input policy is provided.

## 简体中文

这是维护者实际运行的一次小型开发练习：后端角色负责实现，测试角色独立编写并运行测试，
审查角色检查代码和执行证据。工作流规则直接取自 1.0.7 源码，不代表已验证全新安装的
Skill 发现过程，也不能算作外部用户采用记录。

把本目录复制到可丢弃的本地项目中，运行上面的 unittest 命令即可复现最终代码的测试。
原始运行使用 Python 3.12.14，仅依赖标准库。4 个测试方法覆盖 22 个场景，包括双向参考值、
小数和往返转换，绝对误差容限为 `1e-9`。

[执行记录](evidence/run.md)说明了实际的 Red、Green、角色分工和审查结果。人工验收、
实际运行模型、安装发现、性能和成本收益均未得到验证。示例没有界面、命令行应用、联网功能，
也没有增加物理范围校验或无效、极端输入处理规则。
