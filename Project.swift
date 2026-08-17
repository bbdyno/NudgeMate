import ProjectDescription

let marketingVersion = "1.1.0"
let releaseBuildNumber = "2026081701"
let developmentTeam = "M79H9K226Y"

let project = Project(
    name: "NudgeMate",
    organizationName: "NudgeMate",
    options: .options(
        defaultKnownRegions: ["ko", "en", "zh-Hans", "zh-Hant", "ja"],
        developmentRegion: "ko",
        disableSynthesizedResourceAccessors: false
    ),
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
                "NudgeMatePrivacyPolicyURL": "https://bbdyno.github.io/NudgeMate/privacy.html",
                "NSSupportsLiveActivities": true,
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
                .target(name: "NudgeMateWidgets")
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
