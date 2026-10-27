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
            (.outlinedCircle, .determinate), (.ring, .annularDeterminate),
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
        let recorder = HUDChangeRecorder()
        let modeObservation = recorder.observe(hud, \.mode) { observed in
            #expect(observed.mode == .customView)
            #expect(observed.customView === custom)
        }
        let viewObservation = recorder.observe(hud, \.customView) { observed in
            #expect(observed.mode == .customView)
            #expect(observed.customView === custom)
        }
        defer {
            modeObservation.invalidate()
            viewObservation.invalidate()
        }
        hud.setContent(.custom(custom))
        #expect(custom.superview === hud.bezelView)
        #expect(recorder.count == 2)
        hud.setContent(.custom(custom))
        #expect(recorder.count == 2)
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

    @Test(arguments: [false, true])
    func completeBuiltInSelectionDoesNotAdoptCustomIndicator(useSpinner: Bool) {
        let hud = TMProgressHud(frame: .zero)
        let custom: UIView
        if useSpinner {
            custom = UIActivityIndicatorView(style: .medium)
        } else {
            custom = TMRoundProgressView()
        }
        hud.setContent(.custom(custom))
        hud.setContent(useSpinner ? .activity : .ring)
        hud.updateConstraintsIfNeeded()
        #expect(hud.customView == nil)
        #expect(custom.superview == nil)
        if let spinner = custom as? UIActivityIndicatorView {
            #expect(!spinner.isAnimating)
        } else if let round = custom as? TMRoundProgressView {
            #expect(!round.isAnnular)
        }
    }

    @Test(arguments: [false, true])
    func completeBuiltInSelectionReleasesCustomNativeIndicator(useSpinner: Bool) {
        let hud = TMProgressHud(frame: .zero)
        weak var released: UIView?
        autoreleasepool {
            let custom: UIView = useSpinner ? UIActivityIndicatorView(style: .medium) : TMRoundProgressView()
            released = custom
            hud.setContent(.custom(custom))
            hud.updateConstraintsIfNeeded()
            hud.setContent(useSpinner ? .activity : .ring)
            hud.updateConstraintsIfNeeded()
        }
        #expect(released == nil)
    }

    @Test func repeatedBarSelectionPreservesItsViewAndClientStyling() throws {
        let hud = TMProgressHud(frame: .zero)
        hud.setContent(.bar)
        let bar = try #require(hud.indicator as? TMBarProgressView)
        bar.progressColor = .green
        hud.progress = 0.5
        hud.setContent(.bar)
        hud.mode = .determinateHorizontalBar
        #expect(hud.indicator === bar)
        #expect(bar.progressColor == .green)
        #expect(bar.progress == 0.5)
    }

    @Test(arguments: [false, true])
    func builtInBarDoesNotAdoptACustomBar(useTypedSelection: Bool) throws {
        let hud = TMProgressHud(frame: .zero)
        hud.defaultIndicatorColor = .red
        let custom = TMBarProgressView()
        hud.setContent(.custom(custom))
        custom.progressColor = .green
        hud.progress = 0.5
        if useTypedSelection {
            hud.setContent(.bar)
        } else {
            hud.mode = .determinateHorizontalBar
        }
        let bar = try #require(hud.indicator as? TMBarProgressView)
        #expect(bar !== custom)
        #expect(custom.superview == nil)
        #expect(custom.progressColor == .green)
        #expect(bar.progressColor == .red)
        #expect(bar.progress == 0.5)
    }

    @Test func completeSelectionsReuseLibraryOwnedCircularIndicator() {
        let hud = TMProgressHud(frame: .zero)
        hud.setContent(.ring)
        let round = hud.indicator as? TMRoundProgressView
        round?.progressTintColor = .green
        hud.setContent(.outlinedCircle)
        #expect(hud.indicator === round)
        #expect(round?.isAnnular == false)
        #expect(round?.progressTintColor == .green)
    }

    @Test func completeSelectionReleasesCustomIndicatorAfterCompatibilityReuse() {
        let hud = TMProgressHud(frame: .zero)
        let custom = TMRoundProgressView()
        hud.setContent(.custom(custom))
        hud.mode = .determinate
        #expect(hud.indicator === custom)
        hud.customView = nil
        hud.setContent(.ring)
        #expect(custom.superview == nil)
        #expect(!custom.isAnnular)
    }

    @Test func equalSelectionEndsCompatibilityAdoptionOfCustomIndicator() {
        let hud = TMProgressHud(frame: .zero)
        let custom = TMRoundProgressView()
        hud.setContent(.custom(custom))
        hud.mode = .annularDeterminate
        #expect(hud.indicator === custom)
        hud.customView = nil
        hud.setContent(.ring)
        #expect(custom.superview == nil)
        #expect(hud.indicator !== custom)
    }

}
