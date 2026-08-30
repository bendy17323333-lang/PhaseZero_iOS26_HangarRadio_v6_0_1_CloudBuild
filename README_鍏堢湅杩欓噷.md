# 零点相位 6.0.1：GitHub 云端 IPA 构建包

这是一个干净的 GitHub Actions 仓库包，用于在没有 Mac 的情况下调用 GitHub 的 macOS 运行器编译未签名 IPA。

## 使用

1. **推荐新建一个空 GitHub 仓库**，再上传本包的内部文件。不要覆盖到旧工程上。旧仓库里残留的三个音乐原型文件正是本次两条编译错误的来源。
2. 确认 `.github/workflows/build-ipa.yml` 位于仓库根目录。不要把整个 ZIP 当成单个文件上传。
3. 打开 GitHub 仓库的 **Actions**。
4. 运行 **Build Phase Zero Music unsigned IPA**。
5. 构建成功后，从 Artifacts 下载 `PhaseZero-HangarRadio-6.0.1-unsigned-ipa`。
6. 成功时下载 `PhaseZero-HangarRadio-6.0.1-unsigned-ipa`；失败时下载 `PhaseZero-HangarRadio-6.0.1-build-log`。
7. 其中的 `.ipa` 仍是未签名产物，需要用 AltStore、SideStore、Signulous 或自己的开发证书重签名后安装。

## 这版修复的云端编译问题

- 移除仅在 iOS 26.4+ 可写的 `affectsListeningHistory`；它本身默认就是 `true`。
- 歌单队列先加载 `Playlist.entries`，再把第一项传给 `startingAt:`。
- Swift Package 中使用 `Bundle.module`，XcodeGen App 中自动改用 `Bundle.main`。
- 修复嵌套 `SettingsStore` 的 SwiftUI Binding。
- 把护盾特效的巨大 SwiftUI 表达式拆成单独 View，避免编译器超时。
- 不再使用已弃用的 `UIScreen.main`。
- 构建脚本会删除旧仓库中残留的 `MusicModels.swift`、`MusicPlayerService.swift` 和 `MusicPlayerView.swift`。

## Apple Music

IPA 能否成功编译与 Apple Music 能否授权播放是两回事。要让 MusicKit 自动管理令牌，最终用于签名的显式 App ID 需要在 Apple Developer 的 App Services 中启用 MusicKit，并与工程 Bundle ID 一致。
