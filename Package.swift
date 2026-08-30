// swift-tools-version: 6.0

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "PhaseZeroIOS26HangarRadio606",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .iOSApplication(
            name: "零点相位",
            targets: ["AppModule"],
            bundleIdentifier: "com.asher.phasezero.ios26hangarradio600",
            displayVersion: "6.0.6",
            bundleVersion: "16",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
            supportedDeviceFamilies: [
                .phone,
                .pad
            ],
            supportedInterfaceOrientations: [
                .landscapeLeft,
                .landscapeRight
            ],
            appCategory: .games,
            additionalInfoPlistContentFilePath: "AppInfo.plist"
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources/AppModule",
            resources: [
                .process("Resources")
            ]
        )
    ],
    // Swift 5 language mode keeps Swift Playground's imported Objective-C
    // delegates from turning harmless SDK annotation mismatches into errors.
    swiftLanguageModes: [.v5]
)
