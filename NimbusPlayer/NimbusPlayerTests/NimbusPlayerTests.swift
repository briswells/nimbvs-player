import XCTest
@testable import NimbusPlayer

final class NimbusPlayerTests: XCTestCase {
    func testAppStatDefaults() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let state = AppState(defaults: defaults)

        XCTAssertEqual(state.defaultPlaybackSpeed, 1.0)
        XCTAssertEqual(state.skipForwardDuration, 30)
        XCTAssertEqual(state.skipBackwardDuration, 30)
        XCTAssertEqual(state.resumeRewindSeconds, 5)
        XCTAssertFalse(state.downloadOverCellular)
        XCTAssertFalse(state.autoRemoveFinishedDownloads)
        XCTAssertEqual(state.appearanceMode, .system)
    }
}
