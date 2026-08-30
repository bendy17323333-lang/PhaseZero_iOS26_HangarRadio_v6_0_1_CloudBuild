# 零点相位 6.0.3：iPhone 全屏尺寸修复

截图里的界面不是普通的 SwiftUI 缩放错误，而是整个 App 被 iOS 放进了旧式 480×320 兼容画布，所以左右出现了大块黑边，所有 UI 也一起按错误尺寸布局。

本版加入真正编译的 `LaunchScreen.storyboard`，并在云构建中强制检查：

- 最终 App 包含 `LaunchScreen.storyboardc`；
- `Info.plist` 中的 `UILaunchStoryboardName` 为 `LaunchScreen`；
- `UIDeviceFamily` 包含 iPhone；
- iPhone 同时声明左右横屏；
- IPA 内仍包含 HTML、隐私清单与 Asset Catalog。

## 构建

1. 推荐新建空 GitHub 仓库。
2. 上传本文件夹内部的全部内容，包括隐藏的 `.github`。
3. 进入 Actions。
4. 运行 `Build Phase Zero 6.0.3 unsigned IPA`。
5. 下载 `PhaseZero-HangarRadio-6.0.3-unsigned-ipa`。
6. 使用你的签名工具签名并安装。

成功产物还包含 `fullscreen-diagnostics.txt`。它应显示：

```text
UILaunchStoryboardName='LaunchScreen'
UIDeviceFamily=[1, 2]
```

先尝试覆盖安装。仍然保留旧式黑边时，说明系统缓存了旧启动规格；删除旧 App、重启 iPhone 后再安装。删除 App 会清除尚未备份的本地进度。
