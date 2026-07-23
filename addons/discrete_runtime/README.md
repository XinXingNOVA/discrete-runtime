# Discrete Runtime

Discrete Runtime 是一个面向 Godot 4 的离散阶段执行核心。它适合回合制战斗、棋盘流程、
规则结算、工作流模拟，以及其他需要确定顺序、明确因果和异步边界的系统。

Runtime 不持有具体玩法状态，也不依赖 UI。玩法通过 Entry、Handler、Applier、Processor、
ResultEmitter 与 Interpreter 接入。

## 最小心智模型

```text
DiscreteRuntime：负责阶段、出口解释与生命周期状态
└─ DiscreteWorkspace：负责一个阶段内的观察、排序、应用与收束
   ├─ PhaseRequest：请求阶段语义工作
   ├─ Operation：命令式或异步工作
   ├─ Effect：请求状态变更
   ├─ Fact：记录实际发生的变更
   ├─ Result：正常阶段出口
   └─ Signal：终止、中断或重定向出口
```

默认调度顺序：

```text
观察到闭包
→ 较小优先级整数的 Effect 批次
→ Fact 批次
→ 一个 Operation
→ PhaseRequest 批次
→ 稳定后由 ResultEmitter 生成 Result
```

## 安装

将整个 `addons/discrete_runtime/` 目录复制到 Godot 4.6 项目的同名位置：

```text
res://addons/discrete_runtime/
```

Runtime 使用 `class_name` 提供类型，不需要 Autoload，也不是 EditorPlugin。Godot 完成一次
脚本扫描后即可直接使用 `DiscreteRuntime`、`DiscreteWorkspace`、`EffectEntry` 等类型。

当前验证基线为 Godot 4.6.3。其他 Godot 4 特性版本将在调度契约稳定后加入兼容矩阵。

本目录以 MIT License 发布，许可证全文见同目录 `LICENSE`。

## 基本装配步骤

1. 创建由玩法拥有的状态对象。
2. 创建 `DiscreteWorkspace`，注册 Router、Applier、Processor 与 ResultEmitter。
3. 创建 `DiscreteRuntime` 并绑定 Workspace。
4. 注册 Phase。
5. 绑定 Result/Signal Interpreter。
6. 调用 `start()`，随后按需 `await advance()`。

最小推进循环：

```gdscript
runtime.start(&"initial_phase", {})
while await runtime.advance():
	pass

if runtime.get_status() == DiscreteRuntime.Status.TERMINATED:
	print("协议正常结束")
else:
	push_error(runtime.get_last_error_message())
```

`advance()` 返回 `true` 表示本次推进成功得到一个阶段出口；返回 `false` 时，应通过
`get_status()` 区分正常终止与失败。

## Runtime 状态

| 状态 | 含义 |
|---|---|
| `NOT_STARTED` | 尚未成功调用 `start()` |
| `READY` | 已准备好执行当前阶段 |
| `ADVANCING` | 正在运行或等待异步 Operation |
| `EXITED` | 当前阶段已结束，持有待解释出口 |
| `TERMINATED` | Interpreter 没有给出下一阶段，协议正常结束 |
| `FAILED` | 发生配置或调度错误 |

同一 Runtime 不允许并发调用 `advance()`。第二次调用会返回 `false` 并记录错误，但不会
打断已经在执行的第一次调用。

## Signal 出口模式

`SignalEntry` 支持两种模式：

- `SignalEntry.ExitMode.IMMEDIATE`：立即中断剩余调度。
- `SignalEntry.ExitMode.AFTER_SETTLEMENT`：锁定出口，结算完当前活动工作后再退出。

延迟 Signal 适合“胜负已经确定，但逻辑反应仍须完整结算”的场景。进入结算状态后，
Processor 可以通过 `workspace.is_settling_exit()` 跳过输入等待或冗余表现。

## 确定性与失败

- Effect 的优先级整数越小越早执行。
- 相同优先级按 Entry `seq` 升序组成批次。
- Handler、Applier、Processor 和 ResultEmitter 都按注册顺序工作。
- Applier 覆盖不完整、缺少 Processor、稳定后没有 Result、非法 Outcome 等情况会明确失败。
- Entry 获得单调递增的 `seq` 与 Runtime ID；显式序号会推进内部计数器。

## 示例与测试

- 最小示例：`examples/minimal_runtime/MinimalRuntimeDemo.tscn`
- Runtime 契约测试：`tests/runtime/`

运行测试：

```bash
GODOT_BIN=/path/to/godot scripts/run_tests.sh
```

更详细的调度语义见 `docs/runtime-scheduling-contract.md`。

如果只复制了发布包中的 addon，完整契约和项目历史以 Discrete Runtime 源码仓库为准。
