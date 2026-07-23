# Discrete Runtime

Discrete Runtime 是一个确定性的离散阶段运行核心。当前仓库提供 Godot 4.6 的
GDScript 参考实现，用来组织 Entry 调度、Effect/Fact 因果链、异步 Operation 边界，
以及明确的阶段出口和生命周期状态。

它不持有具体玩法状态，也不依赖 UI、场景树或某一种游戏类型。调度模型本身不限定
语言或引擎；`addons/discrete_runtime/` 是目前经过验证的首个实现。

> English summary: Discrete Runtime is a deterministic discrete-phase runtime model.
> This repository contains its first reference implementation for Godot 4.6 in GDScript.

## 仓库内容

```text
addons/discrete_runtime/   Runtime 发布源码
examples/minimal_runtime/  不依赖玩法/UI 的最小示例
tests/runtime/             GUT 契约测试
addons/gut/                固定版本的开发测试依赖
docs/                      调度契约、使用方法与验证证据
scripts/                   本地验证脚本
```

## 快速开始

1. 将 `addons/discrete_runtime/` 复制到你的 Godot 4.6 项目。
2. 让 Godot 完成一次脚本扫描。
3. 创建 `DiscreteWorkspace` 与 `DiscreteRuntime`，注册领域扩展点。
4. 调用 `start()`，再通过 `await advance()` 推进。

Runtime 通过 `class_name` 提供类型，不需要 Autoload，也不是 EditorPlugin。

正式版本的 GitHub Release 会提供只包含 `addons/discrete_runtime/` 的安装 ZIP。

## 运行最小示例

```bash
/path/to/godot --headless --path . \
  examples/minimal_runtime/MinimalRuntimeDemo.tscn
```

或：

```bash
GODOT_BIN=/path/to/godot scripts/run_example.sh
```

首次运行时，脚本会先执行一次无界面项目导入，确保全新解压目录也能建立 Godot 全局类型缓存。

成功输出中的 `runtime_status_name` 应为 `TERMINATED`，计数器 `value` 与 `target`
均为 `3`。

## 运行测试

```bash
GODOT_BIN=/path/to/godot scripts/run_tests.sh
```

当前契约套件包含 21 个测试和 94 个断言。错误路径测试会有意触发并断言
`push_error`，所以测试日志中会出现预期错误行。

## 构建发布包

```bash
scripts/build_release.sh
GODOT_BIN=/path/to/godot scripts/verify_release_package.sh
```

构建脚本在 `dist/` 生成 addon-only ZIP 和 `SHA256SUMS.txt`。验证脚本会检查包内路径，
将它安装到一个全新临时 Godot 项目，并运行最小示例。`dist/` 是本地产物，不进入 Git。

## 文档

- [Runtime 使用说明](addons/discrete_runtime/README.md)
- [最小示例说明](examples/minimal_runtime/README.md)
- [调度契约](docs/runtime-scheduling-contract.md)
- [领域规则映射指南](docs/domain-rule-mapping-guide.md)
- [跨玩法验证报告](docs/cross-game-validation-report.md)
- [测试说明](tests/runtime/README.md)
- [AI 使用入口](AI_GUIDE.md)
- [贡献指南](CONTRIBUTING.md)
- [变更记录](CHANGELOG.md)
- [发布检查清单](docs/release-checklist.md)

## 项目边界

- Runtime 仓库只发布调度核心、最小示例、契约和测试。
- 完整玩法、UI、资源组织方式和项目层参考架构不属于 Runtime API。
- `Offer`、`Commit`、`ContentPack`、`Projector` 等上层模式可以与 Runtime 配合，
  但使用 Runtime 并不要求采用它们。

当前版本为 `v0.1.0`，验证基线为 Godot 4.6.3。在 `1.0.0` 之前，
公共 API 仍可能根据跨领域实现证据发生不兼容调整，变更会记录在版本说明中。

## 许可证

项目由 XinXingNOVA 以 [MIT License](LICENSE) 发布。开发测试依赖的独立许可
见 [第三方软件说明](THIRD_PARTY_NOTICES.md)。
