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

    // MARK: - Description HTML

    func testPlainTextConvertsBreaksAndStripsTags() {
        let html = "An Apple Books Classic edition.<br /><br />Fall down the <i>proverbial</i> rabbit hole.<BR>Is it a daydream?"
        XCTAssertEqual(
            CachedBook.plainText(fromHTML: html),
            "An Apple Books Classic edition.\n\nFall down the proverbial rabbit hole.\nIs it a daydream?"
        )
    }

    func testPlainTextSeparatesParagraphsAndListItems() {
        let html = "<p>First paragraph.</p><p>Second paragraph.</p><ul><li>One</li><li>Two</li></ul>"
        XCTAssertEqual(
            CachedBook.plainText(fromHTML: html),
            "First paragraph.\n\nSecond paragraph.\n\n• One\n• Two"
        )
    }

    func testPlainTextDecodesEntities() {
        XCTAssertEqual(
            CachedBook.plainText(fromHTML: "Tom &amp; Jerry &quot;quoted&quot; &#39;x&#39; caf&#233; &#x2014; &lt;b&gt;&nbsp;end"),
            "Tom & Jerry \"quoted\" 'x' café — <b> end"
        )
        // Decoding happens once: an escaped entity stays an entity.
        XCTAssertEqual(CachedBook.plainText(fromHTML: "&amp;lt;"), "&lt;")
    }

    func testPlainTextLeavesPlainDescriptionsAlone() {
        XCTAssertEqual(CachedBook.plainText(fromHTML: "  Just text, 3 < 4.  "), "Just text, 3 < 4.")
    }
}

