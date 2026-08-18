import ProjectDescription

let marketingVersion = "1.1.0"
let releaseBuildNumber = "2026081701"
let developmentTeam = "M79H9K226Y"
let skAdNetworkIdentifiers = [
    "cstr6suwn9.skadnetwork",
    "4fzdc2evr5.skadnetwork",
    "2fnua5tdw4.skadnetwork",
    "ydx93a7ass.skadnetwork",
    "p78axxw29g.skadnetwork",
    "v72qych5uu.skadnetwork",
    "ludvb6z3bs.skadnetwork",
    "cp8zw746q7.skadnetwork",
    "3sh42y64q3.skadnetwork",
    "c6k4g5qg8m.skadnetwork",
    "s39g8k73mm.skadnetwork",
    "wg4vff78zm.skadnetwork",
    "3qy4746246.skadnetwork",
    "f38h382jlk.skadnetwork",
    "hs6bdukanm.skadnetwork",
    "mlmmfzh3r3.skadnetwork",
    "v4nxqhlyqp.skadnetwork",
    "wzmmz9fp6w.skadnetwork",
    "su67r6k2v3.skadnetwork",
    "yclnxrl5pm.skadnetwork",
    "t38b2kh725.skadnetwork",
    "7ug5zh24hu.skadnetwork",
    "gta9lk7p23.skadnetwork",
    "vutu7akeur.skadnetwork",
    "y5ghdn5j9k.skadnetwork",
    "v9wttpbfk9.skadnetwork",
    "n38lu8286q.skadnetwork",
    "47vhws6wlr.skadnetwork",
    "kbd757ywx3.skadnetwork",
    "9t245vhmpl.skadnetwork",
    "a2p9lx4jpn.skadnetwork",
    "22mmun2rn5.skadnetwork",
    "44jx6755aq.skadnetwork",
    "k674qkevps.skadnetwork",
    "4468km3ulz.skadnetwork",
    "2u9pt9hc89.skadnetwork",
    "8s468mfl3y.skadnetwork",
    "klf5c3l5u5.skadnetwork",
    "ppxm28t8ap.skadnetwork",
    "kbmxgpxpgc.skadnetwork",
    "uw77j35x4d.skadnetwork",
    "578prtvx9j.skadnetwork",
    "4dzt52r2t5.skadnetwork",
    "tl55sbb4fm.skadnetwork",
    "c3frkrj4fj.skadnetwork",
    "e5fvkxwrpn.skadnetwork",
    "8c4e2ghe7u.skadnetwork",
    "3rd42ekr43.skadnetwork",
    "97r2b46745.skadnetwork",
    "3qcr597p9d.skadnetwork"
]
let skAdNetworkItems: [Plist.Value] = skAdNetworkIdentifiers.map {
    ["SKAdNetworkIdentifier": .string($0)]
}

let project = Project(
    name: "NudgeMate",
    organizationName: "NudgeMate",
    options: .options(
        defaultKnownRegions: ["ko", "en", "zh-Hans", "zh-Hant", "ja"],
        developmentRegion: "ko",
        disableSynthesizedResourceAccessors: false
    ),
    packages: [
        .remote(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            requirement: .exact("13.8.0")
        ),
        .remote(
            url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git",
            requirement: .exact("3.1.0")
        )
    ],
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.9"
        ]
    ),
    targets: [
        .target(
            name: "NudgeMate",
            destinations: .iOS,
            product: .app,
            bundleId: "com.bbdyno.app.nudgemate",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "NudgeMate",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "CFBundleLocalizations": [
                    "ko",
                    "en",
                    "zh-Hans",
                    "zh-Hant",
                    "ja"
                ],
                "NSCalendarsFullAccessUsageDescription": "NudgeMate는 반복 일정의 주기를 분석하기 위해 캘린더 전체 접근 권한이 필요합니다.",
                "CFBundleURLTypes": [
                    [
                        "CFBundleTypeRole": "Editor",
                        "CFBundleURLSchemes": ["nudgemate"]
                    ]
                ],
                "ITSAppUsesNonExemptEncryption": false,
                "GADApplicationIdentifier": "ca-app-pub-8965771939775493~6712972291",
                "NudgeMatePrivacyPolicyURL": "https://bbdyno.github.io/NudgeMate/privacy.html",
                "NSSupportsLiveActivities": true,
                "SKAdNetworkItems": .array(skAdNetworkItems),
                "UILaunchScreen": [:],
                "UIAppFonts": [
                    "Pretendard-Regular.otf",
                    "Pretendard-Medium.otf",
                    "Pretendard-SemiBold.otf",
                    "Pretendard-Bold.otf"
                ]
            ]),
            sources: ["NudgeMate/**", "NudgeMateShared/**"],
            resources: ["NudgeMate/Resources/**"],
            entitlements: .file(path: "NudgeMate/NudgeMate.entitlements"),
            dependencies: [
                .target(name: "NudgeMateWidgets"),
                .package(product: "GoogleMobileAds"),
                .package(product: "GoogleUserMessagingPlatform")
            ],
            settings: .settings(
                base: [
                    "CODE_SIGN_STYLE": "Automatic",
                    "DEVELOPMENT_TEAM": .string(developmentTeam),
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "CURRENT_PROJECT_VERSION": .string(releaseBuildNumber),
                    "MARKETING_VERSION": .string(marketingVersion),
                    "PRODUCT_NAME": "NudgeMate",
                    "SWIFT_EMIT_LOC_STRINGS": "NO",
                    "TARGETED_DEVICE_FAMILY": "1,2"
                ]
            )
        ),
        .target(
            name: "NudgeMateWidgets",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "com.bbdyno.app.nudgemate.widget",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "NudgeMate",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "CFBundleLocalizations": [
                    "ko",
                    "en",
                    "zh-Hans",
                    "zh-Hant",
                    "ja"
                ],
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
                ]
            ]),
            sources: ["NudgeMateWidgets/**", "NudgeMateShared/**"],
            resources: ["NudgeMateWidgets/Resources/**"],
            entitlements: .file(path: "NudgeMateWidgets/NudgeMateWidgets.entitlements"),
            settings: .settings(
                base: [
                    "APPLICATION_EXTENSION_API_ONLY": "YES",
                    "CODE_SIGN_STYLE": "Automatic",
                    "CURRENT_PROJECT_VERSION": .string(releaseBuildNumber),
                    "DEVELOPMENT_TEAM": .string(developmentTeam),
                    "MARKETING_VERSION": .string(marketingVersion),
                    "SKIP_INSTALL": "YES",
                    "SWIFT_EMIT_LOC_STRINGS": "NO",
                    "TARGETED_DEVICE_FAMILY": "1,2"
                ]
            )
        ),
        .target(
            name: "NudgeMateTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.bbdyno.app.nudgemate.tests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["NudgeMateTests/**"],
            dependencies: [
                .target(name: "NudgeMate")
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "5.9"
                ]
            )
        ),
        .target(
            name: "NudgeMateUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "com.bbdyno.app.nudgemate.uitests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["NudgeMateUITests/**"],
            dependencies: [
                .target(name: "NudgeMate")
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "NudgeMate",
            shared: true,
            buildAction: .buildAction(targets: ["NudgeMate"]),
            testAction: .targets([
                .testableTarget(target: "NudgeMateTests", parallelization: .enabled),
                .testableTarget(target: "NudgeMateUITests", parallelization: .disabled)
            ]),
            runAction: .runAction(
                executable: "NudgeMate",
                options: .options(
                    storeKitConfigurationPath: "NudgeMate/Resources/NudgeMate.storekit"
                )
            )
        )
    ],
    resourceSynthesizers: [
        .strings()
    ]
)
