# Build Fix Report — Phase Zero 6.0.5

## 6.0.4 日志结论

- Xcode 26.6 完成 Swift 编译、链接、资源编译和 LaunchScreen storyboard 编译。
- `** BUILD SUCCEEDED **` 后，后处理脚本报 `NSAppleMusicUsageDescription is missing after repair`。
- GitHub 仓库中的 `BuildSupport/Info.plist` 原本包含该键，但 XcodeGen 在生成工程时重写了同一路径的 plist。

## 根因

`project.yml` 使用：

```yaml
info:
  path: BuildSupport/Info.plist
```

这不是“引用现有 plist”，而是要求 XcodeGen生成并写入 plist。未在 `properties:` 中声明的自定义字段因此被覆盖。

## 6.0.5 修改

1. 删除 target 的 `info:` 生成器。
2. 使用 `INFOPLIST_FILE: BuildSupport/Info.plist` 引用现有文件。
3. 在 XcodeGen 前后计算源 plist SHA-256，若发生变化则停止构建。
4. 构建前验证 Apple Music、Motion、LaunchScreen 和横屏方向字段。
5. 修复脚本为 Apple Music 与 Motion 使用说明增加独立兜底值。
6. 修复脚本先打印输入状态，再执行验证，避免再次只留下含糊的一行错误。
7. 最终 `.app` 和 `.ipa` 都验证启动屏、方向、设备族、隐私字段与资源。
8. 版本更新为 6.0.5 / Build 15；Bundle ID 保持不变。

## 预期结果

XcodeGen 不再修改 `BuildSupport/Info.plist`，Xcode 的 processed Info.plist 应直接保留完整字段；后处理修复仅作为安全兜底。
