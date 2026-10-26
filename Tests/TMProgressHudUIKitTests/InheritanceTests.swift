import Testing
import UIKit
import TMProgressHudUIKit

@MainActor
private final class GetterConfiguredHUD: TMProgressHud {
    private let providedProgress: Progress = {
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 25
        return progress
    }()

    override var contentColor: UIColor? {
        get { .blue }
        set { super.contentColor = newValue }
    }
    override var progressObject: Progress? {
        get { providedProgress }
        set { super.progressObject = newValue }
    }
}

@Suite(.serialized)
@MainActor
struct InheritanceTests {
    @Test func bulkColorReadsTheOverriddenGetter() {
        let hud = GetterConfiguredHUD(frame: .zero)
        hud.contentColor = .red
        #expect(hud.contentColor == .blue)
        #expect(hud.label.textColor == .blue)
        #expect(hud.detailsLabel.textColor == .blue)
    }

    @Test func progressObservationUsesTheOverriddenGetter() throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = GetterConfiguredHUD.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        #expect(hud.progressObject?.fractionCompleted == 0.25)
        #expect(hud.progress == 0.25)
        let alternate = Progress(totalUnitCount: 1)
        alternate.completedUnitCount = 1
        hud.progressObject = alternate
        #expect(hud.progressObject !== alternate)
        #expect(hud.progress == 0.25)
    }
}
