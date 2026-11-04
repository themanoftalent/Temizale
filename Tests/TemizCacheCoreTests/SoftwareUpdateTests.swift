import XCTest
@testable import TemizCacheCore

final class SoftwareUpdateTests: XCTestCase {

    func testVersionComparison() {
        XCTAssertTrue(SoftwareUpdateScanner.isVersion("2.0.0", newerThan: "1.9.9"))
        XCTAssertTrue(SoftwareUpdateScanner.isVersion("1.10.0", newerThan: "1.9.0"))
        XCTAssertTrue(SoftwareUpdateScanner.isVersion("1.0.1", newerThan: "1.0.0"))
        XCTAssertFalse(SoftwareUpdateScanner.isVersion("1.0.0", newerThan: "1.0.0"))
        XCTAssertFalse(SoftwareUpdateScanner.isVersion("1.0.0", newerThan: "1.0.1"))
        XCTAssertFalse(SoftwareUpdateScanner.isVersion("0.9.9", newerThan: "1.0.0"))
    }

    func testUpdateSources() {
        XCTAssertTrue(UpdateSource.brewCask.isApplication)
        XCTAssertTrue(UpdateSource.mas.isApplication)
        XCTAssertFalse(UpdateSource.brewFormula.isApplication)
        XCTAssertFalse(UpdateSource.npm.isApplication)
        XCTAssertFalse(UpdateSource.pip.isApplication)

        XCTAssertEqual(UpdateSource.brewCask.shortTitle, "Cask")
        XCTAssertEqual(UpdateSource.brewFormula.shortTitle, "Formula")
    }

    func testSoftwareUpdateItemEqualityAndHash() {
        let item1 = SoftwareUpdateItem(
            id: "brew:node",
            name: "node",
            installedVersion: "20.0.0",
            latestVersion: "22.0.0",
            source: .brewFormula,
            rawIdentifier: "node"
        )
        let item2 = SoftwareUpdateItem(
            id: "brew:node",
            name: "node",
            installedVersion: "20.0.0",
            latestVersion: "22.0.0",
            source: .brewFormula,
            rawIdentifier: "node"
        )
        XCTAssertEqual(item1, item2)
        XCTAssertEqual(item1.hashValue, item2.hashValue)
    }

    func testCommandRunnerDefaultPathContainsHomebrew() {
        let path = CommandRunner.defaultPath
        XCTAssertTrue(path.contains("/opt/homebrew/bin") || path.contains("/usr/local/bin"))
    }
}
