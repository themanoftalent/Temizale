import XCTest
@testable import TemizCacheCore

final class AppUninstallerTests: XCTestCase {

    func testLeftoverCategoryProperties() {
        XCTAssertEqual(LeftoverCategory.bundle.systemImage, "app.fill")
        XCTAssertEqual(LeftoverCategory.caches.systemImage, "sparkles")
        XCTAssertFalse(LeftoverCategory.preferences.title.isEmpty)
    }

    func testInstalledAppCalculations() {
        let dummyBundle = URL(fileURLWithPath: "/Applications/Test.app")
        let item1 = AppLeftoverItem(name: "Test.app", url: dummyBundle, category: .bundle, bytes: 100, isSelected: true)
        let item2 = AppLeftoverItem(name: "com.test.plist", url: dummyBundle, category: .preferences, bytes: 50, isSelected: false)

        let app = InstalledApp(
            id: dummyBundle.path,
            name: "Test",
            displayName: "Test App",
            bundleIdentifier: "com.test.app",
            bundleURL: dummyBundle,
            version: "1.0",
            leftovers: [item1, item2]
        )

        XCTAssertEqual(app.totalBytes, 150)
        XCTAssertEqual(app.selectedBytes, 100)
        XCTAssertEqual(app.selectedCount, 1)
    }

    func testUninstallMovesToTrashOrDeletes() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dummyFile = tempDir.appendingPathComponent("dummy.txt")
        try "test data".write(to: dummyFile, atomically: true, encoding: .utf8)

        let item = AppLeftoverItem(name: "dummy.txt", url: dummyFile, category: .other, bytes: 9, isSelected: true)
        let app = InstalledApp(id: "test", name: "Test", displayName: "Test", bundleIdentifier: nil, bundleURL: dummyFile, version: "1.0", leftovers: [item])

        let result = await AppUninstallerExecutor.uninstall(app: app, items: [item], mode: .delete)
        XCTAssertEqual(result.removedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dummyFile.path))
    }
}
