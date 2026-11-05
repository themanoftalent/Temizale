import XCTest
@testable import TemizCacheCore

final class FolderAppearancePolicyTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FolderAppearancePolicyTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testAppearanceFileNamesRecognition() {
        let iconURL = tempDirectory.appendingPathComponent("Icon\r")
        let dsStoreURL = tempDirectory.appendingPathComponent(".DS_Store")
        let localizedURL = tempDirectory.appendingPathComponent(".localized")
        let normalURL = tempDirectory.appendingPathComponent("regular.cache")

        XCTAssertTrue(FolderAppearancePolicy.isFolderColorOrIconFile(iconURL))
        XCTAssertTrue(FolderAppearancePolicy.isFolderColorOrIconFile(dsStoreURL))
        XCTAssertTrue(FolderAppearancePolicy.isFolderColorOrIconFile(localizedURL))
        XCTAssertFalse(FolderAppearancePolicy.isFolderColorOrIconFile(normalURL))
    }

    func testCleaningPreservesIconAndAppearanceFiles() throws {
        let fm = FileManager.default

        // Create mock cache directory structure: tempDirectory/Library/Caches/TestApp
        let cacheFolder = tempDirectory.appendingPathComponent("Library/Caches/TestApp")
        try fm.createDirectory(at: cacheFolder, withIntermediateDirectories: true)

        // Inside cacheFolder, create:
        // 1. Icon\r (folder custom icon)
        let iconURL = cacheFolder.appendingPathComponent("Icon\r")
        try "icon-binary-data".data(using: .utf8)!.write(to: iconURL)

        // 2. .DS_Store (Finder view and position metadata)
        let dsStoreURL = cacheFolder.appendingPathComponent(".DS_Store")
        try "dsstore-data".data(using: .utf8)!.write(to: dsStoreURL)

        // 3. Regular cleanable cache files
        let cacheFile1 = cacheFolder.appendingPathComponent("data.db")
        try "db-cache".data(using: .utf8)!.write(to: cacheFile1)

        let cacheFile2 = cacheFolder.appendingPathComponent("blob.tmp")
        try "temp-cache".data(using: .utf8)!.write(to: cacheFile2)

        // Create a custom-icon styled subfolder
        let subfolderWithIcon = cacheFolder.appendingPathComponent("StyledSubfolder")
        try fm.createDirectory(at: subfolderWithIcon, withIntermediateDirectories: true)
        let subIcon = subfolderWithIcon.appendingPathComponent("Icon\r")
        try "sub-icon".data(using: .utf8)!.write(to: subIcon)

        // Perform clean
        let target = CacheTarget(
            id: "testapp",
            title: "TestApp",
            summary: "Test App Cache",
            kind: .app,
            paths: ["~/Library/Caches/TestApp"]
        )
        let cleaner = Cleaner(home: tempDirectory, mode: .delete)
        let report = cleaner.clean(target, fileManager: fm)

        // Verify normal cache files were removed
        XCTAssertFalse(fm.fileExists(atPath: cacheFile1.path), "Regular cache file should be removed")
        XCTAssertFalse(fm.fileExists(atPath: cacheFile2.path), "Regular cache file should be removed")
        XCTAssertEqual(report.removedItems, 2)

        // Verify Icon\r and .DS_Store were preserved
        XCTAssertTrue(fm.fileExists(atPath: iconURL.path), "Folder custom icon 'Icon\\r' MUST be preserved")
        XCTAssertTrue(fm.fileExists(atPath: dsStoreURL.path), "Finder '.DS_Store' MUST be preserved")

        // Verify styled subfolder was preserved
        XCTAssertTrue(fm.fileExists(atPath: subfolderWithIcon.path), "Subfolder with custom icon MUST be preserved")
        XCTAssertTrue(fm.fileExists(atPath: subIcon.path), "Subfolder 'Icon\\r' MUST be preserved")
    }

    func testPreserveAppearanceHelperRestoresAttributes() throws {
        let folder = tempDirectory.appendingPathComponent("StyledFolder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let iconURL = folder.appendingPathComponent("Icon\r")
        try "my-custom-icon".data(using: .utf8)!.write(to: iconURL)

        FolderAppearancePolicy.preserveAppearance(of: folder) {
            // Even if an internal operation mistakenly removed Icon\r:
            try? FileManager.default.removeItem(at: iconURL)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.path), "preserveAppearance should restore missing Icon\\r")
    }
}
