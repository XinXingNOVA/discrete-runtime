# 贡献指南

感谢你帮助改进 Discrete Runtime。项目优先保持核心语义小、确定且可验证，不以增加 API
数量为目标。

## 报告问题

请提供：

- Godot 版本和操作系统；
- 最小复现项目或测试；
- 期望的语义顺序；
- 实际语义轨迹和完整错误信息；
- 是否能够在不修改 Runtime 的情况下由领域扩展解决。

一般使用问题、文档歧义和已知 API 的缺陷可以直接提交 Issue。

## 提出 Runtime 变更

调度核心的新增能力应同时满足：

1. 当前 Phase、Entry、Handler、Applier、Processor、Emitter 和 Interpreter 无法表达；
2. 问题属于调度语义，不只是某个项目的内容或 UI 架构；
3. 最好已经在两个不同领域中重复出现；
4. 能提供失败轨迹、目标轨迹和最小契约测试。

Offer、Commit、Revision、ContentPack、Catalog、Projector、存档格式、联网策略和 UI 协议
默认属于项目层，不自动进入 Runtime。

## 提交修改

1. 从最新主分支创建短分支。
2. 保持修改范围单一。
3. 为行为变化增加或更新契约测试。
4. 同步更新调度契约和变更记录。
5. 运行：

```bash
scripts/check_boundaries.sh
GODOT_BIN=/path/to/godot scripts/run_example.sh
GODOT_BIN=/path/to/godot scripts/run_tests.sh
```

错误路径测试会有意产生由 GUT 断言的 `push_error`。请根据最终汇总和退出码判断结果。

## 文档与代码风格

- 面向使用者的主要文档使用中文；必要时可以补充英文摘要或翻译。
- 公共类型和标识符继续使用现有英文命名。
- 不在 Runtime 中引入具体玩法、UI 或资源路径。
- 不依赖 Dictionary 迭代、对象地址、帧时序或 SceneTree 子节点顺序表达调度顺序。
- 新文件使用 LF 换行，脚本保持现有 GDScript 风格。
