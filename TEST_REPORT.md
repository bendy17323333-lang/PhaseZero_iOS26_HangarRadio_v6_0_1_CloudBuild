# Phase Zero 6.0.5 local/static verification

## Passed

- `project.yml` 与 GitHub Actions YAML 解析
- 确认 target 不含 XcodeGen `info:` 生成器
- 确认 `INFOPLIST_FILE = BuildSupport/Info.plist`
- BuildSupport Info.plist、AppInfo.plist、PrivacyInfo.xcprivacy 解析
- Bash 构建脚本语法检查
- Python 修复脚本编译检查
- 修复脚本使用正常源 plist 的模拟测试
- 修复脚本在源 plist 缺少两个隐私字符串时的独立兜底测试
- 42 个 Swift 源文件与 Package.swift 语法解析
- 151,185 字节 JavaScript 语法检查
- 5 个 Asset Catalog JSON 文件解析

## Not available in this environment

- XcodeGen 实际工程生成
- Xcode 26 / iOS 26 SDK 编译
- 真机签名、安装和 MusicKit授权

这些步骤由 GitHub Actions 与目标 iPhone完成。构建脚本新增源 plist 哈希检查，使下一份日志能够明确证明 XcodeGen 是否仍修改该文件。
