## 修改内容

简要说明本次修改解决的问题。

## 边界

- [ ] 没有向 Runtime 引入具体玩法、UI 或外部资源依赖。
- [ ] 行为变化已经同步更新契约、测试和变更记录。
- [ ] 新增 Runtime 能力附有最小跨领域证据，或已说明为什么无需跨领域证据。

## 验证

- [ ] `scripts/check_boundaries.sh`
- [ ] `GODOT_BIN=/path/to/godot scripts/run_example.sh`
- [ ] `GODOT_BIN=/path/to/godot scripts/run_tests.sh`
- [ ] 若影响发布内容，已运行 `scripts/build_release.sh` 和
      `scripts/verify_release_package.sh`
