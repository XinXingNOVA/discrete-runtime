# 变更记录

本项目遵循语义化版本。`1.0.0` 之前的版本可能根据跨领域验证结果调整公共 API，
不兼容变化会在这里明确记录。

## [0.1.0] - 2026-07-24

### 新增

- 确定性的阶段内 Entry 调度。
- PhaseRequest、Operation、Effect、Fact、Result 与 Signal 六类 Entry。
- Effect/Fact 因果链与观察闭包。
- 同步 Applier、异步 Operation Processor 和阶段 ResultEmitter。
- `IMMEDIATE` 与 `AFTER_SETTLEMENT` 两种 Signal 出口模式。
- Runtime 六态生命周期、失败信息和并发 `advance()` 保护。
- 最小无 UI 示例。
- 21 个测试、94 个断言组成的 Runtime 契约套件。

### 文档

- Runtime 调度契约。
- 领域规则映射指南。
- 跨玩法验证报告。
- AI 与首次使用者入口。
