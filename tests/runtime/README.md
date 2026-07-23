# Discrete Runtime 契约测试

## 目的

本测试套件定义 `DiscreteRuntime` 和 `DiscreteWorkspace` 的公共调度行为，
并且有意不加载任何具体玩法或 UI 类型。

测试依赖为固定在 `res://addons/gut/` 下的 GUT 9.6.1。GUT 属于开发基础设施，
不能包含在 Runtime 插件的发布产物中。

## 运行命令

在 Godot 项目根目录执行：

```bash
/path/to/godot --headless -d -s --path "$PWD" addons/gut/gut_cmdln.gd
```

也可以从任意目录使用仓库提供的封装脚本：

```bash
GODOT_BIN=/path/to/godot scripts/run_tests.sh
```

仓库中的 `.gutconfig.json` 会选择本目录；测试失败时，命令以非零状态码退出。

## 测试层次

### 冒烟测试（Smoke）

验证 Godot、GUT 与 Runtime 全局类可以一起加载。冒烟测试不涉及有争议的调度语义。

### 特征测试（Characterization）

保留核心加固前的基线证据，并与当前行为进行对照。公共语义以
`docs/runtime-scheduling-contract.md` 和通过的契约断言共同表达。

### 契约测试（Contract）

表达 v0.1.0 对外承诺的行为。公共行为发生缺陷修正或不兼容调整时，必须同步更新契约、
测试和变更记录。

### 集成测试（Integration）

使用伪状态和伪 Processor 运行一组完整的合成阶段流程。集成测试不依赖 UI，
并且必须具有确定性。

## 测试矩阵

| 分组 | 用例 |
|---|---|
| 阶段 | start、未知阶段、激活上下文、Result 跳转、Signal 跳转、正常终止 |
| 身份 | 单调递增 seq、生成 ID、保留显式 ID、保留来源信息 |
| 观察 | Handler 顺序、派生 Entry 生命周期、失效、替代、恰好观察一次 |
| Effect | 优先级方向、seq 决胜、批处理、首个匹配 Applier、覆盖不完整 |
| Fact | Fact 批处理、反应、致命 Fact 加反应、终止顺序 |
| Operation | 逐个分派、等待与恢复、返回 Entry、缺少 Processor、并发 advance |
| Request | 批次覆盖、失效、Handler 产生的工作 |
| Outcome | 派生 Entry、Result 选择、Signal 优先、拒绝出口与派生项混合 |
| 稳定 | ResultEmitter 顺序、无 Result 失败、安全上限失败 |
| 复用 | reset、第二次 start、合成轨迹的确定性 |

## 当前覆盖

第三阶段核心加固完成时，Runtime-only 套件包含 3 个测试脚本、21 个测试和 94 个断言，
覆盖以下已批准契约：

- 观察闭包、Effect 优先级和相同优先级批次顺序；
- Signal 的立即中断与结算后提交模式；
- Runtime 六态生命周期与并发推进保护；
- Entry 身份、显式序号同步、来源保留与 reset；
- Handler、Applier 和 ResultEmitter 注册顺序；
- 失效、覆盖不完整、缺少 Processor、无 Result 稳定失败和非法混合 Outcome；
- 延迟 Signal 相对于后续普通 Result 的出口优先级。

错误路径测试会有意触发 `push_error`；GUT 对相应错误文本进行了断言，因此控制台中的
这些错误行属于预期测试输出。

## 测试夹具规则

- 夹具使用 `TestDiscrete` 前缀，并放在本目录下。
- 夹具绝不导入具体玩法或 UI。
- 领域状态使用由测试持有的小型 `RefCounted` 对象或 Dictionary。
- 异步测试使用可以显式控制的伪 Processor，不使用按实际时间 sleep。
- 顺序断言比较记录下来的语义事件，不比较控制台文本。
- 预期中的 `push_error` 必须通过 GUT 错误跟踪处理。
- 每个回归问题都要有能够复现它的最小测试。

## 版本策略

- Godot 基线：4.6.3
- GUT 基线：9.6.1（`c80954f47bed74a0a2c471d472c0389f98e0a8f6`）
- Runtime 基线：v0.1.0

只有通过对应版本的完整契约套件后，才会扩大 Godot 兼容性声明。
