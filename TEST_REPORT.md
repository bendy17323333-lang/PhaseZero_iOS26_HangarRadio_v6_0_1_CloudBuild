# Hangar Radio 6.0.1 检查报告

## 1. 测试基线

本版以已经在用户设备上达到高刷新率的 Phone Ready 5.2 分支为稳定基线。没有重新引入 V5.1 中曾导致卡死的复杂 HUDStore 和实验性全局渲染闭环。

新增范围：

- 六机型永久成长系统；
- 演算点结算与特性升级；
- 隐藏实验室越权；
- Apple Music 资料库与播放队列；
- 相位电台和设置页紧凑播放器；
- 程序性音频可视化；
- seek / settings slider 局部状态与延迟提交；
- WebKit 外部音乐 BGM ducking。

## 2. 静态结构检查

已完成：

- `Package.swift` 通过本地 `swiftc -parse`；
- 42 个 Swift 源文件逐个通过 `swiftc -parse`；
- 内置 HTML 中 151,185 字节 JavaScript 通过 `node --check`；
- `AppInfo.plist` 与 `PrivacyInfo.xcprivacy` 均可解析；
- Asset Catalog 的全部 `Contents.json` 均可解析；
- App 图标、深色图标、着色图标和启动图均存在；
- iPhone / iPad、左右横屏、iOS 26、版本 6.0.1 与 Build 11 声明存在；
- `NSAppleMusicUsageDescription` 与 `NSMotionUsageDescription` 存在。

注意：`swiftc -parse` 只验证 Swift 语法结构，不替代 iOS SDK 类型检查。Apple API 最终是否通过编译，仍由 Swift Playground / Xcode 的 iOS 26 SDK 决定。

## 3. JavaScript 战斗核心运行测试

通过无界面 Chromium 加载完整内置 HTML，并从原生 Bridge 依次注入六种满级机型。页面错误与 Console 错误均为 0。

验证结果：

| 机型 | 关键实测状态 |
|---|---|
| AX-01 衡轴 | 6 HP、1 护盾、1 次复活、过载冲击波、强化换相 |
| VX-07 逐矢 | 3 次冲刺、3.6 冲刺伤害、终点冲击、自动换相 |
| PR-13 棱镜 | 永久双相射击、征用 9 枚敌弹、棱镜风暴 |
| HV-03 蜂巢 | 4 架无人机、强化无人机射速与追踪、维修掉率提高 |
| RX-66 灾变 | 4 HP、1.33 倍主武器伤害、连锁爆炸、3 枚死亡碎片、14% 处决 |
| OR-00 先见 | 4 次总重抽、强化软锁、1.9 追踪、20% 暴击、12% 处决 |

同时验证：

- 机型得分倍率与裂隙倍率可组合；
- `start`、`menu` 与 `settings` Bridge 命令可连续执行；
- `externalMusicActive` 能进入网页设置；
- 页面错误：0；
- Console error / warning：0。

## 4. 永久成长数据检查

代码层面已检查：

- 初始只解锁 AX-01；
- 解锁价格为 0 / 8 / 12 / 16 / 20 / 26 Φ；
- 特性升级价格为 2 / 4 / 6 Φ；
- 有效特性等级限制在 1…4；
- 单局演算点限制在 0…15；
- 每日奖励使用挑战 ID 防止重复领取；
- 越权只设置 `laboratoryOverride`，不销毁真实点数、解锁和特性存档；
- 越权状态下未来机型也会按解锁和满级处理。

## 5. 音频与进度条优化检查

代码路径已检查：

- `DeferredSeekSlider` 在拖动期间只更新局部 `@State`；
- `ApplicationMusicPlayer.playbackTime` 只在松手后写入一次；
- 拖动时可视化暂停；
- Slider 事务明确关闭隐式动画；
- Apple Music 队列元数据只在 `title + subtitle` 身份改变时重新发布；
- 播放进度监控为播放时 250 ms、暂停时 900 ms；
- 可视化刷新上限约 24 FPS；
- 可视化柱体合并为 3 个 Path 批量填充；
- `DeferredSettingSlider` 将连续设置值保留在局部状态，松手才提交；
- `SettingsStore` 以 110 ms 合并持久化和 Bridge 推送；
- 页面关闭时 flush 待写入设置。

这些结构能够消除已知的“拖动进度条导致整个设置界面高频重建”路径，但真机 FPS 改善仍需使用 iPad / iPhone 的系统实验室和性能 HUD测量。

## 6. Apple Music 尚需真机验证的项目

当前环境没有 MusicKit SDK 运行时和 Apple Developer App ID，因此以下项目尚未声称通过：

- `MusicAuthorization` 实际系统弹窗；
- `MusicLibraryRequest<Song>` 与 `MusicLibraryRequest<Playlist>` 返回内容；
- `ApplicationMusicPlayer.Queue` 的真机播放；
- Apple Music 封面图加载；
- 当前签名 Bundle ID 的 MusicKit App Service；
- 无订阅、仅已购/同步音乐时的资料库行为；
- 真机 seek 精度和曲目切换状态更新。

工程对授权拒绝、系统限制、MusicKit 不可用和疑似 App Service 缺失均提供了可见错误状态，不会因为音乐接入失败而阻断原有游戏。

## 7. 建议真机回归顺序

1. 首次启动与主菜单 FPS；
2. 机库解锁、装备、升级和重启后的存档；
3. 六机型各开一局，核对 HUD 与实际效果；
4. Apple Music 授权与资料库加载；
5. 歌曲、歌单、上一首、下一首和暂停；
6. 连续拖动进度条 10 秒，记录 FPS 与触控延迟；
7. Apple Music 播放时进入战斗，确认合成 BGM 让位但音效保留；
8. 切后台再回来，确认播放状态与 WebKit 设置恢复；
9. 系统实验室隐藏越权；
10. iPhone 灵动岛左右方向和 iPad 窗口缩放。
