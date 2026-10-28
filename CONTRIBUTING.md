# 贡献指南

感谢帮助改进 Daylist。请先阅读 [README](README.md) 中的功能边界和 [验证记录](VERIFICATION.md)，了解当前实现及尚未覆盖的系统集成测试。

## 本地开发

1. Fork 仓库并创建功能分支。
2. 安装完整 Xcode，复制 `Config/Local.xcconfig.example` 为 `Config/Local.xcconfig`。
3. 使用自己的 Bundle ID、App Group 和开发团队，在 Xcode 中运行 `Daylist` Scheme。
4. 提交前执行 `swift test`；只有 Command Line Tools 时可使用 `./Scripts/test-core.sh`。

## 修改原则

- 每日完成记录按当地日期计算，避免改为依赖午夜后台任务清空状态。
- App 和 Widget 的读写都应通过 `ChecklistStore`，保留文件锁和原子写入。
- 编辑事项不能覆盖编辑期间其他进程产生的完成记录。
- 修改提醒逻辑时覆盖时区、夏令时、限额、完成取消和一次性事项的行为。
- 修改存储格式时明确考虑 schema 版本和已有数据；损坏文件不可静默重置。
- 保持 iOS 17 最低部署版本；采用更新 API 时提供兼容处理或说明版本变更。
- 不要将系统尽力调度的后台刷新或小组件刷新描述为实时保证。

## 提交问题

请提供 iOS / Xcode 版本、设备型号、复现步骤、预期与实际结果。涉及提醒时补充时区、事项重复规则、提醒时间和通知授权状态。截图及日志请先删除个人清单、账号、设备标识和签名信息。

## Pull Request

说明解决的问题、实际行为变化和验证结果。界面修改可以附真实截图；核心规则修改应补充能防止回归的测试。请区分「核心测试通过」和「已经在真机验证」。

## 不应提交的文件

`Config/Local.xcconfig`、证书和私钥、provisioning profile、IPA、构建缓存、Xcode 用户状态、真实清单文件和设备日志均不应提交。发布补丁时也不要把它们包含在 diff 中。

贡献按仓库的 [MIT 许可证](LICENSE) 提供。
