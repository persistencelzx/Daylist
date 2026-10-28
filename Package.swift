// swift-tools-version: 5.9
import PackageDescription

// Build the iOS app and widget with Daylist.xcodeproj. `swift test` requires XCTest.
// On a Mac with Command Line Tools only, use Scripts/test-core.sh instead.
let package = Package(
    name: "DaylistCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "DaylistCore", targets: ["DaylistCore"])],
    targets: [
        .target(name: "DaylistCore", path: "Shared",
                exclude: ["Reminders.swift", "CompleteTaskIntent.swift"],
                sources: ["Core.swift", "Store.swift", "ReminderPlan.swift"]),
        .testTarget(name: "DaylistCoreTests", dependencies: ["DaylistCore"], path: "Tests")
    ]
)
