# 零点相位 6.0.6：机库 / 相位电台运行时修复

这是基于 6.0.5 完整云构建分支的增量版本，Bundle ID 保持：

```text
com.asher.phasezero.ios26hangarradio600
```

因此原有 MusicKit App Service 配置无需重建。

## 本次修复

- 删除机库左上角无动作的 `Φ` 状态胶囊；点数仍显示在机型特性区域。
- 删除相位电台左上角无动作的 Apple Music 状态胶囊；授权状态移到内容区。
- Apple Music 授权后，游戏原声不再从电台界面消失。
- 新增“游戏原声”来源与四个程序合成循环，可在电台中切换、暂停和恢复。
- Apple Music 与游戏原声共用统一正在播放面板和音频可视化。
- 修复 `MPMusicPlayerControllerErrorDomain Code 2` 造成的陈旧错误横幅：
  - 串行化队列切换；
  - 取消过期播放任务；
  - 队列切换前先让游戏原声淡出；
  - 检测到新队列已经播放时，把旧队列错误视为过期事件；
  - 仅在新队列确实未播放时显示友好错误。
- 游戏原声的噪声节拍现在也经过独立音乐总线；“压低游戏原声”不会漏出节拍噪声，同时射击与命中音效继续保留。

## 现有仓库更新

解压 `PhaseZero_iOS26_HangarRadio_v6_0_6_RuntimeHotfix_ONLY.zip`，把最外层文件夹内部内容按原路径覆盖到仓库根目录。必须确认隐藏的 `.github` 文件夹也已上传。

随后运行：

```text
Build Phase Zero 6.0.6 unsigned IPA
```

成功产物：

```text
PhaseZero-HangarRadio-6.0.6-unsigned-ipa
```

其中包含：

```text
PhaseZero-HangarRadio-6.0.6-unsigned.ipa
PhaseZero-HangarRadio-6.0.6-unsigned.ipa.sha256
source-plist-diagnostics.txt
fullscreen-diagnostics.txt
ipa-metadata-diagnostics.txt
```

## 干净仓库构建

也可以使用完整 `PhaseZero_iOS26_HangarRadio_v6_0_6_CloudBuild.zip`：

1. 新建空 GitHub 仓库。
2. 解压完整包。
3. 上传解压后目录内部的全部内容。
4. 在 Actions 运行 `Build Phase Zero 6.0.6 unsigned IPA`。
5. 下载 unsigned IPA，再使用你的签名工具重签并安装。

## 推荐真机测试

1. 打开机库，确认左上角只剩系统导航区域，不再出现无动作 `f(x)` 胶囊。
2. 打开相位电台，确认左上角不再出现无动作状态按钮。
3. 已授权 Apple Music 的情况下，确认右侧仍有“游戏原声”区。
4. 播放一首 Apple Music 曲目，确认游戏原声按设置淡出，射击等音效仍可用。
5. 连续快速点击两首歌，确认不会长期留下错误 2 横幅。
6. Apple Music 暂停后选择任意游戏原声，确认程序音乐恢复。
7. 关闭“Apple Music 播放时压低游戏原声”，确认允许两者同时输出。

如果 Apple Music 曲目完全无法开始播放，而不是“已经播放但显示旧错误”，请保留设备控制台中包含 `MPMusicPlayerControllerErrorDomain` 的完整行。不同错误码需要分别处理。
