import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class ReentrantRoundView: TMRoundProgressView {
    var onStyleChange: (() -> Void)?

    override var isAnnular: Bool {
        get { super.isAnnular }
        set {
            super.isAnnular = newValue
            let callback = onStyleChange
            onStyleChange = nil
            callback?()
        }
    }
}

@MainActor
private final class ReentrantContentView: UIView, TMProgressHudProgressReporting {
    var onAttachment: (() -> Void)?
    var onRemoval: (() -> Void)?
    var onColor: (() -> Void)?
    var onProgress: (() -> Void)?
    private(set) var attachments = 0
    private(set) var receivedProgress: [Float] = []
    var progress: Float = 0 {
        didSet {
            receivedProgress.append(progress)
            let callback = onProgress
            onProgress = nil
            callback?()
        }
    }

    override var tintColor: UIColor! {
        get { super.tintColor }
        set {
            super.tintColor = newValue
            let callback = onColor
            onColor = nil
            callback?()
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        let callback: (() -> Void)?
        if superview == nil {
            callback = onRemoval
            onRemoval = nil
        } else {
            attachments += 1
            callback = onAttachment
            onAttachment = nil
        }
        callback?()
    }
}

@Suite(.serialized)
@MainActor
struct ContentSelectionTests {
    @Test func priorObserversSeeTheOldSelectionAndPostObserversSeeTheCompleteSelection() {
        let hud = TMProgressHud(frame: .zero)
        let custom = UIView()
        let recorder = HUDChangeRecorder()
        var modeSnapshots: [TMProgressHudMode] = []
        var customViewSnapshots: [Bool] = []
        let modeObservation = recorder.observe(hud, \.mode, options: [.prior, .new]) { observed in
            modeSnapshots.append(observed.mode)
            #expect((observed.mode == .customView) == (observed.customView === custom))
        }
        let viewObservation = recorder.observe(hud, \.customView, options: [.prior, .new]) { observed in
            customViewSnapshots.append(observed.customView === custom)
            #expect((observed.mode == .customView) == (observed.customView === custom))
        }
        defer {
            modeObservation.invalidate()
            viewObservation.invalidate()
        }
        hud.setContent(.custom(custom))
        #expect(modeSnapshots == [.indeterminate, .customView])
        #expect(customViewSnapshots == [false, true])
        #expect(recorder.count == 4)
        hud.setContent(.custom(custom))
        #expect(recorder.count == 4)
    }

    @Test func postObserverCanSelectTheNextContentWithoutBeingOverwritten() throws {
        let hud = TMProgressHud(frame: .zero)
        let custom = UIView()
        let recorder = HUDChangeRecorder()
        let observation = recorder.observe(hud, \.customView) { observed in
            if observed.customView === custom { observed.setContent(.bar) }
        }
        defer { observation.invalidate() }
        hud.progress = 0.5
        hud.setContent(.custom(custom))
        let bar = try #require(hud.indicator as? TMBarProgressView)
        #expect(hud.mode == .determinateHorizontalBar)
        #expect(hud.customView == nil)
        #expect(custom.superview == nil)
        #expect(bar.superview === hud.bezelView)
        #expect(bar.progress == 0.5)
        hud.setContent(.text)
        #expect(hud.indicator == nil)
        hud.setContent(.custom(custom))
        #expect(hud.mode == .determinateHorizontalBar)
        #expect(hud.indicator is TMBarProgressView)
    }

    @Test func nestedSelectionFromAPriorObserverCompletesBeforeTheOuterWrite() {
        let hud = TMProgressHud(frame: .zero)
        let custom = UIView()
        let recorder = HUDChangeRecorder()
        var requestedNestedSelection = false
        let observation = recorder.observe(hud, \.mode, options: [.prior]) { observed in
            guard !requestedNestedSelection else { return }
            requestedNestedSelection = true
            observed.setContent(.bar)
            #expect(observed.mode == .determinateHorizontalBar)
        }
        defer { observation.invalidate() }
        hud.setContent(.custom(custom))
        #expect(requestedNestedSelection)
        #expect(hud.mode == .customView)
        #expect(hud.customView === custom)
        #expect(hud.indicator === custom)
        #expect(custom.superview === hud.bezelView)
    }

    @Test(arguments: [false, true])
    func contentCallbackKeepsTheLatestSelection(onProgress: Bool) {
        let hud = TMProgressHud(frame: .zero)
        hud.progress = 0.5
        let triggeringView = ReentrantContentView()
        let latestView = ReentrantContentView()
        if onProgress {
            triggeringView.onProgress = { hud.setContent(.custom(latestView)) }
        } else {
            triggeringView.onColor = { hud.setContent(.custom(latestView)) }
        }
        hud.setContent(.custom(triggeringView))
        #expect(hud.indicator === latestView)
        #expect(latestView.superview === hud.bezelView)
        #expect(latestView.attachments == 1)
        #expect(latestView.receivedProgress == [0.5])
        #expect(triggeringView.receivedProgress == (onProgress ? [0.5] : []))
        #expect(triggeringView.superview == nil)
    }

    @Test(arguments: [false, true])
    func hierarchyCallbackEndsTheSupersededIndicatorUpdate(onRemoval: Bool) {
        let hud = TMProgressHud(frame: .zero)
        hud.progress = 0.5
        let triggeringView = ReentrantContentView()
        let latestView = ReentrantContentView()
        if onRemoval {
            hud.setContent(.custom(triggeringView))
            triggeringView.onRemoval = { hud.setContent(.custom(latestView)) }
            hud.setContent(.bar)
        } else {
            triggeringView.onAttachment = { hud.setContent(.custom(latestView)) }
            hud.setContent(.custom(triggeringView))
        }
        #expect(hud.indicator === latestView)
        #expect(hud.customView === latestView)
        #expect(latestView.superview === hud.bezelView)
        #expect(latestView.attachments == 1)
        #expect(latestView.receivedProgress == [0.5])
        #expect(triggeringView.superview == nil)
    }

    @Test(arguments: [false, true])
    func styleCallbackCanReplaceTheInFlightSelection(selectBar: Bool) throws {
        let hud = TMProgressHud(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let custom = ReentrantRoundView()
        hud.setContent(.custom(custom))
        custom.onStyleChange = { hud.setContent(selectBar ? .bar : .text) }
        hud.mode = .annularDeterminate
        #expect(hud.mode == (selectBar ? .determinateHorizontalBar : .text))
        #expect(hud.customView == nil)
        #expect(custom.superview == nil)
        if selectBar {
            let bar = try #require(hud.indicator as? TMBarProgressView)
            #expect(bar.superview === hud.bezelView)
        } else {
            try #require(hud.indicator == nil)
        }
        hud.layoutIfNeeded()
    }

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
