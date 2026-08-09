import ProjectDescription

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
            bundleId: "com.nudgemate.app",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "NudgeMate",
                "CFBundleLocalizations": [
                    "ko",
                    "en",
                    "zh-Hans",
                    "zh-Hant",
                    "ja"
                ],
                "NSCalendarsFullAccessUsageDescription": "NudgeMate는 반복 일정의 주기를 분석하기 위해 캘린더 전체 접근 권한이 필요합니다.",
                "UILaunchScreen": [:],
                "UIAppFonts": [
                    "Pretendard-Regular.otf",
                    "Pretendard-Medium.otf",
                    "Pretendard-SemiBold.otf",
                    "Pretendard-Bold.otf"
                ]
            ]),
            sources: ["NudgeMate/**"],
            resources: ["NudgeMate/Resources/**"],
            settings: .settings(
                base: [
                    "CODE_SIGN_STYLE": "Automatic",
                    "CURRENT_PROJECT_VERSION": "1",
                    "MARKETING_VERSION": "1.0.0",
                    "PRODUCT_NAME": "NudgeMate",
                    "SWIFT_EMIT_LOC_STRINGS": "NO",
                    "TARGETED_DEVICE_FAMILY": "1,2"
                ]
            )
        ),
        .target(
            name: "NudgeMateTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.nudgemate.app.tests",
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
        )
    ],
    resourceSynthesizers: [
        .strings()
    ]
)
