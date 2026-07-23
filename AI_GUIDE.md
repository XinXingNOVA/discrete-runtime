# AI 与首次使用者入口

这份文件帮助没有项目背景的使用者或 AI 理解和使用 Discrete Runtime。不要假定任何
未写入仓库的设计背景，也不要从某一种现成玩法反推 Runtime 的通用语义。

## 阅读顺序

建议严格按以下顺序阅读：

1. 根目录 `README.md`：了解定位、目录和验证方式；
2. `addons/discrete_runtime/README.md`：建立核心心智模型；
3. `examples/minimal_runtime/README.md`；
4. `examples/minimal_runtime/minimal_runtime_demo.gd`：阅读完整最小装配；
5. `docs/domain-rule-mapping-guide.md`：把领域规则映射到 Runtime；
6. `docs/runtime-scheduling-contract.md`：需要精确语义时查阅；
7. `tests/runtime/`：需要确认边界或错误行为时阅读。

不要从遍历全部源码开始。先用最小示例形成假设，再用契约和测试验证。

## 需要守住的边界

- 玩法拥有自己的状态，Runtime 不替玩法保存领域状态；
- `Effect` 表示请求发生变更，`Fact` 表示实际已经发生的变更；
- 状态修改集中在 Applier，不要在 Handler 或 Interpreter 中随意修改；
- `Operation` 用于命令式工作或异步边界，不是普通状态变更的替代品；
- `Result` 是正常阶段出口，`Signal` 用于中断、终止或重定向；
- 真正需要截断后续工作时使用 `SignalEntry.ExitMode.IMMEDIATE`；出口已确定但当前逻辑
  仍须完整结算时使用 `AFTER_SETTLEMENT`；
- 同一个 Runtime 不允许并发调用 `advance()`；
- 在证明现有扩展点无法表达需求之前，不要修改 `addons/discrete_runtime/`。

## 开始创作

建议先在独立 Godot 项目中复制 `addons/discrete_runtime/`，再实现一个无 UI 的最小闭环：

```text
领域状态
→ Phase 激活
→ Effect 请求变更
→ Applier 修改状态并产生 Fact
→ Fact 触发必要反应
→ Result 或 Signal 退出
```

先输出可以重复比较的语义轨迹和最终摘要，再接入输入、动画或正式 UI。领域类型应使用
项目自己的唯一前缀，避免 Godot 全局 `class_name` 冲突。

如果认为必须修改 Runtime，请先给出：

1. 无法表达的最小领域规则；
2. 使用现有 Phase、Entry、Handler、Applier、Processor、Emitter 和 Interpreter
   仍然失败的证据；
3. 这个缺口是否在至少两个不同领域中重复出现；
4. 为什么它属于调度语义，而不是项目层架构。

## 本地验证

需要 Godot 4.6。通过环境变量指定可执行文件：

```bash
GODOT_BIN=/path/to/godot scripts/run_example.sh
GODOT_BIN=/path/to/godot scripts/run_tests.sh
scripts/check_boundaries.sh
```

`run_example.sh` 和 `run_tests.sh` 会在首次缺少类型缓存时完成无界面项目导入，因此可直接用于刚解压、尚未用 Godot 编辑器打开过的目录。新增存在继承关系的全局 `class_name` 后，可主动运行：

```bash
GODOT_BIN=/path/to/godot scripts/import_project.sh
```

测试当前应为 21 个测试、94 个断言。错误路径测试会故意触发并断言 `push_error`，日志中出现预期错误行不代表测试失败，应以最终汇总和进程退出码为准。

当前 Godot 4.6.3 基线在无界面进程退出时可能打印 `ObjectDB instances leaked at exit` 和
`resources still in use at exit`。判断结果时应以测试汇总和进程退出码为准，并保留完整
日志以便区分测试失败与引擎退出诊断。

## 遇到不明确之处时

记录最初理解、产生歧义的文件、采用的假设以及验证证据。不要只提交最终成功版本；
第一次误解和最小失败用例同样有助于改进文档与契约。
