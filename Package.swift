// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CmdShelf",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CmdShelf",
            targets: ["CmdShelf"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/mysql-kit.git", from: "4.0.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.3.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.4.1"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "CmdShelf",
            dependencies: [
                .product(name: "MySQLKit", package: "mysql-kit"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/CmdShelf",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
