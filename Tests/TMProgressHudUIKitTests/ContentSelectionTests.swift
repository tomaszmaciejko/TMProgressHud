import Testing
import UIKit
@testable import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct ContentSelectionTests {
    @Test func completeSelectionsMapToCompatibilityModes() {
        let hud = TMProgressHud(frame: .zero)
        for (selection, mode) in [
            (TMProgressHudContent.activity, TMProgressHudMode.indeterminate),
            (.pie, .determinate), (.ring, .annularDeterminate),
            (.bar, .determinateHorizontalBar), (.text, .text),
        ] {
            hud.setContent(selection)
            #expect(hud.mode == mode)
            #expect(hud.customView == nil)
        }
    }

    @Test func observersSeeTheCompleteSelectionAndEqualSelectionIsANoOp() {
        let hud = TMProgressHud(frame: .zero)
        let custom = UIView()
        var changes = 0
        let modeObservation = hud.observe(\.mode, options: [.new]) { observed, _ in
            #expect(observed.mode == .customView)
            #expect(observed.customView === custom)
            changes += 1
        }
        let viewObservation = hud.observe(\.customView, options: [.new]) { observed, _ in
            #expect(observed.mode == .customView)
            #expect(observed.customView === custom)
            changes += 1
        }
        defer {
            modeObservation.invalidate()
            viewObservation.invalidate()
        }
        hud.setContent(.custom(custom))
        #expect(custom.superview === hud.bezelView)
        #expect(changes == 2)
        hud.setContent(.custom(custom))
        #expect(changes == 2)
    }

    @Test func selectingBuiltInContentReleasesCustomContent() {
        let hud = TMProgressHud(frame: .zero)
        weak var reference: UIView?
        autoreleasepool {
            let custom = UIView()
            reference = custom
            hud.setContent(.custom(custom))
            hud.updateConstraintsIfNeeded()
            hud.setContent(.activity)
            hud.updateConstraintsIfNeeded()
        }
        #expect(hud.customView == nil)
        #expect(reference == nil)
        #expect(hud.indicator is UIActivityIndicatorView)
    }

    @Test func compatibilitySettersContinueToPreserveInactiveCustomContent() {
        let hud = TMProgressHud(frame: .zero)
        let custom = UIView()
        hud.customView = custom
        hud.mode = .text
        #expect(hud.customView === custom)
        hud.mode = .customView
        #expect(hud.indicator === custom)
        hud.customView = custom
        hud.mode = .customView
        #expect(hud.indicator === custom)
    }

    @Test func manualSourceStopsPreviousObservation() throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        let source = Progress(totalUnitCount: 100)
        source.completedUnitCount = 60
        hud.setProgressSource(.observed(source))
        #expect(hud.progress == 0.6)
        hud.setProgressSource(.manual(0.25))
        #expect(hud.progressObject == nil)
        #expect(hud.progress == 0.25)
        source.completedUnitCount = 90
        #expect(hud.progress == 0.25)
        hud.hide(animated: false)
        host.addSubview(hud)
        hud.show(animated: false)
        #expect(hud.progress == 0.25)
        hud.setProgressSource(.observed(source))
        #expect(hud.progress == 0.9)
    }
}
