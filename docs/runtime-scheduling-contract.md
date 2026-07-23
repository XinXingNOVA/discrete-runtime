# Runtime 调度契约

## 文档状态

- 状态：v0.1.0 现行契约
- 范围：`addons/discrete_runtime/`
- 效力：由 `tests/runtime/` 中通过的契约测试提供可执行证据
- Runtime 基线：v0.1.0
- 引擎基线：Godot 4.6.3

本文描述 v0.1.0 对外承诺的调度行为。若文字与可执行行为出现矛盾，应先将其视为缺陷，
通过最小复现、契约测试和版本记录明确修正，不能静默改变公共语义。

## 目的

Runtime 以显式阶段执行领域层提供的工作。它不持有玩法状态，也不负责表现层，
但提供确定性的执行顺序、可追踪的因果关系、同步状态变更边界、异步操作边界
以及明确的阶段出口。

本契约涵盖：

- 阶段激活与出口解释；
- Entry 的身份与生命周期；
- 观察与失效；
- 分派顺序与批次选择；
- 异步 Operation 的暂停与恢复；
- 稳定、终止与失败。

本契约不定义领域 Entry 词汇、玩法状态、输入结构、动画命令、回放序列化、
网络同步或随机数策略。

## 已确定的架构约束

以下模型属于 v0.1.0 的公共架构约束。

1. `DiscreteRuntime` 负责阶段激活与出口解释。
2. `DiscreteWorkspace` 负责一个活动阶段内部的工作。
3. 玩法状态由领域层挂接，不归 Runtime 所有。
4. Handler 观察 Entry 并返回 Proposal，不直接修改玩法状态。
5. Applier 执行同步应用工作并返回 `ExecutionOutcome`。
6. Processor 负责命令式或异步的 `OperationEntry` 工作。
7. Result 表示正常阶段出口；Signal 表示终止、异常或重定向出口，并明确声明立即中断或结算后提交。
8. Effect 请求发生变更；Fact 记录实际发生的变更。
9. 每个入队 Entry 都会获得 Runtime ID 和单调递增的序号。
10. 注册顺序属于运行数据，绝不能依赖 SceneTree 子节点顺序。

## Entry 类型

| 类型 | 含义 | 应用边界 |
|---|---|---|
| PhaseRequest | 请求活动阶段执行某项语义工作 | Request applier |
| Operation | 需要命令式或异步处理的工作 | Operation processor |
| Effect | 请求修改玩法状态 | Effect applier |
| Fact | 记录实际发生的状态变更 | Fact applier |
| Result | 正常结束一个阶段 | Runtime result interpreter |
| Signal | 终止、中断或重定向阶段流程 | Runtime signal interpreter |

## 身份与来源

Entry 第一次入队或被选为出口时，必须获得：

- 一个大于零且单调递增的 `seq`；
- 一个非空 Runtime ID；除非调用方显式指定，否则由序号生成；
- 保持不变的既有来源与因果信息。

Runtime Entry ID 不等同于玩法定义 ID，也不等同于玩法实例 ID。

Runtime 不会虚构领域因果关系。已知相应信息时，生产者负责填写
`producer`、`basis`、`parent_id`、`cause_id`、`phase` 和 `window`。
测试必须验证调度过程不会破坏这些信息。

## 阶段协议

预期的外部调用协议为：

```text
start（初始阶段，上下文）
-> 开始 Workspace 阶段
-> 激活阶段并将初始工作入队
-> 运行 Workspace，直到得到 Result 或 Signal
-> 保留待处理出口
-> 在下一次 advance 时解释该出口
-> 激活下一个阶段
```

v0.1 通过 `DiscreteRuntime.Status` 公开区分以下状态：

- `NOT_STARTED`：尚未开始；
- `READY`：可以推进；
- `ADVANCING`：正在推进或等待 Operation；
- `EXITED`：阶段已经退出，并持有待处理出口；
- `TERMINATED`：没有下一阶段，正常终止；
- `FAILED`：执行失败。

Interpreter 返回 `null` 表示没有下一阶段，Runtime 进入 `TERMINATED`，不再与失败共用
同一状态。成功调用 `start()` 可以从先前的 `FAILED` 状态重新初始化 Runtime。

## 观察生命周期

Entry 会经历以下概念状态：

```text
等待观察
-> 观察中
-> 已观察
-> 已失效或被选中分派
-> 已完成
```

对于一条观察记录，每个匹配的 Handler 最多运行一次。Handler 返回的结果按照
Handler 注册顺序合并。派生出来的新 Entry 会获得自己的记录，并且必须经过观察
后才能分派。

失效意味着当前记录不能越过应用边界。如果需要替代 Entry，应通过 Proposal 生成一个
拥有独立身份与观察生命周期的新 Entry，而不是在原记录上设置替代标志。

## 调度循环

Workspace 使用以下循环：

```text
持续观察待处理 Entry，直到达到观察闭包
-> 分派选中的 Effect 批次
-> 分派当前可用的 Fact 批次
-> 处理一个 Operation
-> 应用当前可用的 PhaseRequest 批次
-> 没有剩余工作时，向 ResultEmitter 请求阶段 Result
```

分派产生的所有新 Entry 都要回到观察阶段。循环持续执行，直到选出出口、发生明确
失败或达到配置的安全上限。

“观察闭包”表示在选择应用边界之前，不再存在由观察过程新生成而尚未观察的 Entry。
该规则属于 v0.1.0 契约。

## 确定性顺序

契约测试必须让以下顺序均可观察：

- Handler 注册顺序；
- Applier 注册顺序；
- Processor 注册顺序；
- ResultEmitter 注册顺序；
- Entry 序号顺序；
- Effect 优先级顺序；
- 批次成员顺序；
- 出口选择顺序。

任何顺序都不能依赖 Dictionary 迭代、对象地址、帧时序或场景子节点顺序。

基线会先处理优先级整数较小的 Effect，相同优先级再按序号升序处理。
优先级整数较小者先执行属于 v0.1.0 公共语义。

## 批处理

一个 Effect 批次包含当前已满足条件、未失效且处于选中优先级的全部 Effect。
每个 Effect 由注册顺序中第一个 `can_apply` 返回 `true` 的 Applier 处理。
覆盖必须完整，否则 Workspace 失败。

一个 Fact 批次包含当前已满足条件且未失效的全部 Fact。每个 Fact 由第一个匹配的
已注册 Applier 处理，覆盖同样必须完整。

PhaseRequest 批次采用相同的“首个匹配 Applier”和“完整覆盖”规则。

Operation 按确定性的记录顺序逐个处理。

## 执行结果与出口

`ExecutionOutcome` 可以包含派生 Entry、Result 或 Signal。

基线拒绝同时包含出口和派生 Entry 的结果。v0.1 应保留此规则，否则无法明确出口
之前哪些工作必须完成。

在同一个 Outcome 内，Signal 候选优先于 Result 候选，然后选择序号最小的候选。
不同 Dispatcher 或 Emitter 返回的出口如何竞争，仍需特征测试。

出口一旦被接受，任何未处理 Entry 都不能被悄然视为已经执行。

Signal 必须声明以下出口模式之一：

- `IMMEDIATE`：立即成为 `pending_exit`，中断剩余调度；适用于真正的取消、强制跳转或中断。
- `AFTER_SETTLEMENT`：先锁定为结算出口，继续处理活动工作；Workspace 稳定后再提交为 `pending_exit`。

结算出口一旦锁定，普通 Result 不能覆盖它；后续立即 Signal 可以中断结算并成为最终出口。
多个结算 Signal 按 Entry 序号选择最早者。失败始终立即停止。

`AFTER_SETTLEMENT` 保证逻辑结算完整，但不要求继续播放冗余表现。领域 Applier 与
Operation Processor 应在终止条件已经成立时，让不再适用的工作明确地以 no-op 或
无阻塞方式完成。

## 异步 Operation

匹配的 Processor 处理一个 Operation 时：

1. Workspace 等待该 Processor；
2. 同一 Workspace 不能并发分派其他工作；
3. Operation 记录恰好完成一次；
4. 返回的 Outcome 恰好应用一次；
5. 调度通过正常观察路径继续执行。

同一 Runtime 上并发调用 `DiscreteRuntime.advance()` 必须由核心拒绝。被拒绝的第二次
调用返回 `false` 并留下错误消息，但不能中断或破坏正在执行的第一次调用。第一次调用
完成后，Runtime 进入它原本应到达的状态。

## 稳定状态与 Result 生成

仅当等待观察、观察中和已观察的记录均为空，并且尚未选出出口时，阶段才处于稳定
状态。稳定后，按照注册顺序询问 ResultEmitter；第一个非空 Result 结束阶段。

稳定但没有生成 Result 属于明确失败，而不是成功的空操作。

## 失败模型

至少以下情况必须可被观察为失败：

- 没有 Workspace 就调用 start；
- 使用未知阶段调用 start；
- start 之前调用 advance；
- 没有当前阶段时调用 advance；
- Applier 覆盖不完整；
- 缺少匹配的 Operation processor；
- 稳定后没有 Result；
- 同一个 Outcome 同时包含出口和派生 Entry；
- 耗尽安全循环上限；
- 并发调用 advance。

失败必须能与正常终止区分。

## 安全上限

循环预算是防止错误规则无限运行的保护措施，不是玩法规则。v0.1.0 的 Workspace
为单次 `run_until_exit()` 使用固定的 1024 次循环上限，耗尽后进入明确失败。

基于进度签名或重复状态的检测推迟到 v0.1 之后。

## v0.1.0 已确认的调度决策

| 编号 | 问题 | v0.1.0 决策 |
|---|---|---|
| D-01 | 分派前是否必须达到观察闭包？ | 必须。 |
| D-02 | 优先级整数较小还是较大者先执行？ | 较小值优先，相同优先级按 `seq`。 |
| D-03 | 终止 Signal 能否抢先于 Fact 反应？ | 由 `IMMEDIATE` 与 `AFTER_SETTLEMENT` 显式选择。 |
| D-04 | 如何公开已退出、正常终止和失败状态？ | 使用六态 `DiscreteRuntime.Status`。 |
| D-05 | 应在哪一层拒绝并发 `advance()`？ | 由 `DiscreteRuntime` 核心拒绝。 |
| D-06 | 未使用的 replacement、notes、clone API 是否公开？ | 不进入 v0.1.0 公共 API。 |

D-01 至 D-06 均有 `tests/runtime/` 中的契约断言支持。

## 必需的契约测试分组

可执行契约分为：

- 阶段与出口协议；
- Entry 身份与来源；
- 观察、失效与替代；
- 确定性顺序与批处理；
- Effect 到 Fact 的反应链；
- 异步 Operation 行为；
- 稳定、终止与失败；
- 重置、复用与合成场景的确定性重放。

测试必须使用合成夹具，不能引用任何具体玩法或 UI 类型。
