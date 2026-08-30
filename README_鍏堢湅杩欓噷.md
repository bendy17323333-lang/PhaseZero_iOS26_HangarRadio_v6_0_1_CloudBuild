# 零点相位 6.0.4：iPhone 原生分辨率元数据修复

6.0.3 的 GitHub Actions 日志已经证明：Swift、MusicKit、资源和 `LaunchScreen.storyboardc` 全部编译成功，但 Xcode 26.6 最终生成的 App `Info.plist` 丢失了 `UILaunchStoryboardName` 与横屏方向数组。构建脚本因此主动停止，避免再产出一个可能落入旧式 480×320 兼容画布的 IPA。

6.0.4 不再只依赖 Xcode 的 plist 合并行为。它会在 **Xcode 构建完成后、IPA 打包前** 修复最终 App Bundle 内的 `Info.plist`，随后再从 IPA 内部读取一次并验证。

## 更新现有仓库

解压 `PhaseZero_iOS26_HangarRadio_v6_0_4_MetadataHotfix_ONLY.zip`，把文件夹内部内容上传到仓库根目录并覆盖旧文件。必须保留隐藏的 `.github` 文件夹。

然后运行：

```text
Build Phase Zero 6.0.4 unsigned IPA
```

成功产物：

```text
PhaseZero-HangarRadio-6.0.4-unsigned-ipa
```

里面应有：

```text
PhaseZero-HangarRadio-6.0.4-unsigned.ipa
PhaseZero-HangarRadio-6.0.4-unsigned.ipa.sha256
fullscreen-diagnostics.txt
ipa-metadata-diagnostics.txt
```

两个诊断文件都应显示：

```text
UILaunchStoryboardName='LaunchScreen'
UIDeviceFamily=[1, 2]
```

## 安装

先覆盖安装，以尽量保留机型和演算点进度。仍有左右黑边时，再删除旧 App、重启 iPhone、重新签名并安装 6.0.4。删除 App 会清除未备份的本地进度。
