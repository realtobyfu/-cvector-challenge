import ProjectDescription

let project = Project(
    name: "grove",
    targets: [
        .target(
            name: "grove",
            destinations: .macOS,
            product: .app,
            bundleId: "dev.tuist.grove",
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Grove",
                "CFBundleName": "Grove",
                "CFBundleIconName": "AppIcon",
                "ATSApplicationFontsPath": "Fonts",
            ]),
            buildableFolders: [
                "grove/Sources",
                "grove/Resources",
            ],
            entitlements: .file(path: "grove/grove.entitlements"),
            dependencies: [],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_VERSION": "6.0",
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "CODE_SIGN_STYLE": "Automatic",
                "DEVELOPMENT_TEAM": "679K683SQ5",
                "CODE_SIGN_IDENTITY": "Apple Development",
            ])
        ),
        .target(
            name: "groveTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "dev.tuist.groveTests",
            infoPlist: .default,
            buildableFolders: [
                "grove/Tests"
            ],
            dependencies: [.target(name: "grove")],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_VERSION": "6.0",
            ])
        ),
    ]
)
