# 零点相位 · HANGAR RADIO 6.0.1

V6.0.1 基于已经在 iPhone / iPad 上验证过流畅性的 Phone Ready 5.2 分支扩建。它加入局外机库成长、六种战斗机型、Apple Music 相位电台、设置页音频可视化，以及针对进度条和连续设置滑杆的刷新优化。

这次仍然遵守一条很朴素、却经常被软件项目集体遗忘的规则：新增系统不能拿稳定帧率祭天。

## 一、相位机库与永久成长

游戏加入永久资源 **演算点 Φ**。每局结算会根据波次、Boss 进度、最高 Style、导演裂隙表现和每日裂隙首次完成情况发放，单局最多 15 Φ。

演算点可用于：

- 解锁新机型；
- 升级机型自带的三项特性；
- 保留当前装备机型，作为下一局真实生效的开局职业。

机型与解锁价格：

| 机型 | 定位 | 解锁价格 |
|---|---|---:|
| AX-01 衡轴 | 稳定、防御、过载 | 初始解锁 |
| VX-07 逐矢 | 冲刺、近战、速度 | 8 Φ |
| PR-13 棱镜 | 换相、弹幕转化 | 12 Φ |
| HV-03 蜂巢 | 无人机、集火、修复 | 16 Φ |
| RX-66 灾变 | 爆炸、高伤、高风险 | 20 Φ |
| OR-00 先见 | 预测、弱点、导演交涉 | 26 Φ |

每项特性拥有 I、II、III、IV 四级。升级费用依次为 2、4、6 Φ；IV 级不是单纯多几个百分点，而是会开启复活、冲刺自动换相、永久双相射击、四机编队、连锁碎片或额外导演重抽等新机制。

机型、特性等级和当前演算点均保存在 `UserDefaults` 中。当前有效机型会随开局指令送入 WebKit 战斗核心，实际修改生命、护盾、换相、冲刺、无人机、爆炸、暴击、追踪、重抽和得分倍率，不是机库里摆六张会发光的个人简历。

### 隐藏实验室越权

系统实验室的“辅助功能”能力卡保持普通外观，没有文字、图标、进度、预触感或其他提示。持续按住该卡空白区域约 3 秒后，会启用永久 `laboratoryOverride`：

- 所有机型按已解锁处理；
- 所有特性按 IV 级处理；
- 原始演算点与真实升级进度仍保留在存档下层；
- 后续新增机型也会自动受越权覆盖。

## 二、Apple Music 相位电台

新增完整原生音乐界面：

- 系统级 Apple Music / 媒体资料库授权；
- 读取资料库歌曲和歌单；
- 使用 `ApplicationMusicPlayer` 建立 App 自己的播放队列；
- 播放、暂停、上一首、下一首和拖动进度；
- 当前曲目标题、艺人、时长和封面；
- Apple Music 播放时，可自动压低游戏内合成 BGM，但保留射击和触觉反馈；
- iPhone 与 iPad 使用同一套响应式 Liquid Glass 电台界面。

设置页也加入紧凑版播放器，完整资料库则从主菜单或设置页进入“相位电台”。

### MusicKit 必要配置

工程已包含：

- `import MusicKit` 的条件编译；
- `NSAppleMusicUsageDescription`；
- 授权、资料库请求、播放队列和错误回退逻辑。

真正访问 Apple Music 时，当前 Bundle ID `com.asher.phasezero.ios26hangarradio600` 对应的 App ID 仍需在 Apple Developer 网站中启用 **MusicKit App Service**。MusicKit 属于服务端绑定的 App Service，不是在 `Package.swift` 里随便添一行“能力”就能骗过苹果。

若当前签名或 App ID 没有完成服务配置，游戏会显示“需要 MusicKit App Service”，而不是让整个项目因为音乐平台的官僚手续一起崩溃。

## 三、音频可视化

设置页和完整相位电台都加入了 24 FPS 的程序性音频可视化：

- 根据当前曲目元数据生成稳定种子；
- 播放时使用连续时间相位驱动频谱；
- 暂停时固定在当前播放位置；
- 拖动进度条时暂时冻结，松手后恢复；
- 28 根柱体按三组 `Path` 批量绘制，避免每根柱体单独切换渲染状态；
- 在 120 Hz 屏幕上仍只以最高约 24 FPS 更新装饰层。

这不是伪装成真实 FFT 的魔术。MusicKit 的公开播放接口没有向应用提供受保护曲目的原始 PCM 缓冲，因此当前版本使用低成本、与歌曲身份和播放状态一致的程序性光谱。以后接入玩家从“文件”App 导入的本地音频时，才适合用 `AVAudioEngine` 做真正的频谱分析。

## 四、进度条与设置页帧率修复

旧式实现的问题是：拖动一个滑杆时，每个像素都会写入全局 `ObservableObject`，随后让设置页所有玻璃面板、陀螺仪层、性能遥测和 WebKit 配置一起更新。一个拇指拖动，整棵视图树便召开紧急会议。

V6.0.1 改为：

### Apple Music 进度条

- 拖动期间只修改 `DeferredSeekSlider` 的局部状态；
- 不连续写入 `ApplicationMusicPlayer.playbackTime`；
- 松手时只提交一次 seek；
- 拖动时冻结音频可视化；
- 明确禁用 Slider 隐式动画；
- 当前曲目标题、封面和时长只在队列条目真正变化时发布，不再每 250 ms 重发相同内容。

### 连续设置滑杆

- 触控透明度和陀螺灵敏度使用 `DeferredSettingSlider`；
- 拖动值只保存在滑杆本地；
- 松手后才更新共享 `SettingsStore`；
- `UserDefaults` 写入和 WebKit 设置推送再以约 110 ms 合并；
- 离开设置页时强制 flush，避免最后一次修改丢失。

## 五、网易云音乐状态

V6.0.1 没有加入非官方接口、明文账号或被抓包后就会集体失效的临时方案。网易云音乐接入保留为下一阶段，计划使用统一 `MusicProvider` 接口、官方开放平台和安全后端。先把 Apple Music 这条路走通，比同时维护两套账号外交关系更像软件开发，而不是国际峰会。

## 六、工程信息

- Minimum OS：iOS / iPadOS 26
- Device Families：iPhone + iPad
- Orientation：Landscape Left + Landscape Right
- Bundle Identifier：`com.asher.phasezero.ios26hangarradio600`
- Version：`6.0.1`
- Build：`11`
- Swift language mode：Swift 5 compatibility under Swift 6 toolchain
- 战斗核心：离线 HTML / JavaScript，随 App 资源打包
- 原生系统层：SwiftUI、Liquid Glass、Core Motion、Core Haptics、GameController、Foundation Models、MusicKit

## 七、在 Swift Playground 中测试

1. 停止旧版正在运行的实例。
2. 解压 `PhaseZero_iOS26_HangarRadio_v6_0_1.swiftpm.zip`。
3. 打开 `PhaseZero_iOS26_HangarRadio_v6_0_1.swiftpm`。
4. 点击运行，先确认 Issues 面板没有红色编译错误。
5. 进入机库，装备不同机型并开局，确认能力真实变化。
6. 进入相位电台并请求授权。
7. 若显示需要 MusicKit App Service，先在 Apple Developer 的 App ID 中启用 MusicKit，并使用完全相同的 Bundle ID 重新构建。
8. 播放一首歌，在设置页拖动播放进度条，观察界面 FPS 是否保持稳定。
9. 进入系统实验室，检查性能 HUD、陀螺仪和 Apple Music 状态。

当前生成环境没有 Xcode、iOS 26 SDK、MusicKit 真机授权环境或 Apple 开发签名。这里完成的是源码实现、Swift 语法解析、JavaScript 运行测试和资源结构检查；最终 Apple SDK 类型检查与 MusicKit 实际播放仍以你的 iPad / iPhone 为准。
