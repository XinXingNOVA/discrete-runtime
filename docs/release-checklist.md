# Runtime 发布检查清单

## 代码与边界

- [x] Runtime 源码不引用具体玩法、UI 或外部资源。
- [x] 最小示例只依赖 `addons/discrete_runtime/`。
- [x] 21 个测试、94 个断言全部通过。
- [x] Godot 4.6.3 最小示例正常终止。
- [x] 封闭预览文件不进入正式仓库。

## 法律与依赖

- [x] 根目录包含 MIT License 和版权声明。
- [x] addon 目录携带相同许可证。
- [x] GUT 与字体许可证保留在第三方目录。
- [x] 第三方依赖不进入用户安装包。
- [ ] 创建公开仓库后启用 GitHub 私密漏洞报告。

## 文档

- [x] README 说明项目定位、边界、安装、测试和版本状态。
- [x] 调度契约与当前实现一致。
- [x] 提供最小示例、领域规则映射指南和 AI 使用入口。
- [x] 跨玩法验证报告不把项目层模式描述成 Runtime 要求。
- [x] 变更记录包含 `v0.1.0` 初始内容。

## 发布工程

- [x] addon-only ZIP 可以重复构建。
- [x] ZIP 只包含 `addons/discrete_runtime/`。
- [x] ZIP 中包含 README 和 LICENSE。
- [x] SHA-256 文件可以重复生成。
- [x] ZIP 可安装到全新项目并运行最小示例。
- [ ] GitHub Actions 在 Linux 上通过完整验证。

## 正式发布

- [ ] 创建 `XinXingNOVA/discrete-runtime` 公开仓库。
- [ ] 核对仓库描述、Topics 和默认分支设置。
- [ ] 推送干净的首个提交并等待 CI 通过。
- [ ] 将 `CHANGELOG.md` 中的待发布日期替换为实际日期。
- [ ] 创建签名或受保护的 `v0.1.0` 标签。
- [ ] 建立 GitHub Release 并上传 ZIP 与 SHA-256。
- [ ] 从 GitHub 下载发布附件并再次验证哈希与安装。
- [ ] 单独准备并提交 Godot Asset Library 条目。

STS 白盒和其他完整玩法案例不属于 Runtime `v0.1.0` 的发布门槛。
