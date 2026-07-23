# 最小 Runtime 示例

这个示例只依赖 `addons/discrete_runtime/`，不依赖具体玩法、UI、场景管理器或其他
项目基础设施。

它用一个从 0 数到 3 的计数器展示最小闭环：

```text
CounterPhase
→ increment Effect
→ CounterEffectApplier 修改状态
→ counter_changed Fact
→ CounterFactApplier 记录结果
→ step_complete Result
→ CounterResultInterpreter 决定继续或正常终止
```

## 运行

在项目根目录执行：

```bash
/path/to/godot --headless --path . \
  examples/minimal_runtime/MinimalRuntimeDemo.tscn
```

成功时会输出一行 JSON 摘要，其中 `value` 与 `target` 均为 `3`，
`runtime_status_name` 为 `TERMINATED`。

## 文件

- `MinimalRuntimeDemo.tscn`：可直接运行的入口场景。
- `minimal_runtime_demo.gd`：状态、Phase、Applier、Emitter、Interpreter 与装配代码。

所有示例类型都定义在一个脚本内，是为了方便首次阅读；实际项目应按职责拆分文件。
