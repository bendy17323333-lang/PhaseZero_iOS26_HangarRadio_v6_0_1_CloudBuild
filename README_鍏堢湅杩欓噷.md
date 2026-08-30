# 零点相位 6.0.5：XcodeGen Info.plist 覆盖修复

6.0.4 的 Xcode 编译本身已经成功，但构建脚本随后报：

```text
NSAppleMusicUsageDescription is missing after repair
```

本次确认根因不是 MusicKit，也不是 Python 无法写入中文字符串，而是 `project.yml` 中使用了 XcodeGen 的 `info:` 生成器。该配置会在每次 `xcodegen generate` 时重新写入指定路径的 Info.plist；由于没有同时在 `info.properties` 中列出自定义键，原来的 Apple Music、陀螺仪、启动屏和方向字段被生成过程覆盖。

6.0.5 改为直接设置：

```yaml
GENERATE_INFOPLIST_FILE: NO
INFOPLIST_FILE: BuildSupport/Info.plist
```

并彻底删除 target 的 `info:` 块。构建脚本会在 XcodeGen 前后计算源 plist 的 SHA-256；只要生成过程再改动它，构建立即失败并指出原因。

## 更新现有仓库

解压 `PhaseZero_iOS26_HangarRadio_v6_0_5_InfoPlistHotfix_ONLY.zip`，把最外层文件夹里的内容按原路径上传到仓库根目录并覆盖旧文件。必须包含隐藏的 `.github` 文件夹。

随后运行：

```text
Build Phase Zero 6.0.5 unsigned IPA
```

成功产物：

```text
PhaseZero-HangarRadio-6.0.5-unsigned-ipa
```

其中应包含：

```text
PhaseZero-HangarRadio-6.0.5-unsigned.ipa
PhaseZero-HangarRadio-6.0.5-unsigned.ipa.sha256
source-plist-diagnostics.txt
fullscreen-diagnostics.txt
ipa-metadata-diagnostics.txt
```

`source-plist-diagnostics.txt` 中，XcodeGen 前后的两个 SHA-256 必须一致。

`ipa-metadata-diagnostics.txt` 中应显示：

```text
UILaunchStoryboardName='LaunchScreen'
UIDeviceFamily=[1, 2]
NSAppleMusicUsageDescription present=True
NSMotionUsageDescription present=True
resource LaunchScreen.storyboardc=True
```

## 安装

优先覆盖安装，以保留演算点和机型进度。若仍处于 480×320 兼容画布，再删除旧 App、重启 iPhone并重新签名安装。删除 App 会清除未备份的本地进度。
