import Testing
import UIKit
import TMProgressHudUIKit

@MainActor
private final class ForeignProgressView: UIView {
    @objc dynamic var progress: Double = 0 {
        didSet { received.append(progress) }
    }
    private(set) var received: [Double] = []
}

@MainActor
private final class TypedProgressView: UIView, TMProgressHudProgressReporting {
    var progress: Float = 0
}

@MainActor
private final class ReportingSpinnerView: UIActivityIndicatorView, TMProgressHudProgressReporting {
    var progress: Float = 0
}

@MainActor
private final class ForeignSpinnerView: UIActivityIndicatorView {
    @objc dynamic var progress: Double = 0
}

@MainActor
private final class ProgressReceiver {
    var received: [Float] = []
}

@Suite(.serialized)
@MainActor
struct CustomProgressMigrationTests {
    @Test func spinnerSubclassReceivesItsDeclaredProgressAndKeepsSpinnerColoring() {
        let hud = TMProgressHud(frame: .zero)
        let spinner = ReportingSpinnerView(style: .medium)
        hud.progress = 0.25
        hud.setContent(.custom(spinner))
        #expect(spinner.progress == 0.25)
        hud.progress = 0.75
        #expect(spinner.progress == 0.75)
        hud.applyContentColor(.orange)
        #expect(spinner.color == .orange)
        #expect(!spinner.isAnimating)
        hud.setContent(.text)
        hud.progress = 1
        #expect(spinner.progress == 0.75)
    }

    @Test func declaredSpinnerProgressSurvivesCompatibilityAdoptionUntilCompleteSelection() {
        let hud = TMProgressHud(frame: .zero)
        let spinner = ReportingSpinnerView(style: .medium)
        hud.setContent(.custom(spinner))
        hud.progress = 0.25
        hud.mode = .indeterminate
        #expect(spinner.superview === hud.bezelView)
        #expect(spinner.isAnimating)
        hud.progress = 0.75
        #expect(spinner.progress == 0.75)
        hud.applyContentColor(.green)
        #expect(spinner.color == .green)
        hud.setContent(.activity)
        #expect(spinner.superview == nil)
        hud.progress = 1
        #expect(spinner.progress == 0.75)
    }

    @Test func noSelectionRouteGuessesAnObjectiveCProgressContract() {
        let hud = TMProgressHud(frame: .zero)
        let custom = ForeignProgressView()
        hud.setContent(.custom(custom))
        hud.progress = 0.4
        #expect(custom.received.isEmpty)
        let spinner = ForeignSpinnerView(style: .medium)
        hud.customView = spinner
        hud.progress = 0.5
        #expect(spinner.progress == 0)
        hud.mode = .indeterminate
        hud.progress = 0.75
        #expect(spinner.isAnimating)
        #expect(spinner.progress == 0)
        hud.mode = .customView
        hud.customView = custom
        hud.progress = 1
        #expect(custom.received.isEmpty)
    }

    @Test func explicitFunctionBridgesAThirdPartySetterWithoutChangingItsView() {
        let hud = TMProgressHud(frame: .zero)
        let custom = ForeignProgressView()
        hud.progress = 0.25
        hud.setContent(.custom(custom, updateProgress: { custom.progress = Double($0) }))
        #expect(custom.received == [0.25])
        hud.progress = 0.75
        #expect(custom.received == [0.25, 0.75])
        #expect(hud.customView === custom)
        #expect(custom.superview === hud.bezelView)
    }

    @Test func replacingTheFunctionOnTheSameViewReappliesProgressWithoutKVO() {
        let hud = TMProgressHud(frame: .zero)
        let custom = ForeignProgressView()
        let first = ProgressReceiver()
        let second = ProgressReceiver()
        hud.progress = 0.4
        hud.setContent(.custom(custom, updateProgress: { first.received.append($0) }))
        let recorder = HUDChangeRecorder()
        let observation = recorder.observe(hud, \.customView) { _ in Issue.record("The view did not change") }
        defer { observation.invalidate() }
        let content = TMProgressHudContent.custom(custom, updateProgress: { second.received.append($0) })
        hud.setContent(content)
        hud.setContent(content)
        hud.progress = 0.7
        #expect(first.received == [0.4])
        #expect(second.received == [0.4, 0.4, 0.7])
        hud.setContent(.custom(custom))
        hud.progress = 0.2
        #expect(second.received == [0.4, 0.4, 0.7])
        #expect(custom.received.isEmpty)
        #expect(recorder.count == 0)
    }

    @Test(arguments: [0, 1, 2, 3])
    func explicitFunctionTakesPrecedenceOverTypedProgress(kind: Int) {
        let hud = TMProgressHud(frame: .zero)
        let view: UIView
        switch kind {
        case 0: view = TMRoundProgressView()
        case 1: view = TMBarProgressView()
        case 2: view = UIProgressView(progressViewStyle: .default)
        default: view = ReportingSpinnerView(style: .medium)
        }
        var received: [Float] = []
        hud.progress = 0.25
        hud.setContent(.custom(view, updateProgress: { received.append($0) }))
        hud.progress = 0.75
        #expect(received == [0.25, 0.75])
        switch view {
        case let circle as TMRoundProgressView: #expect(circle.progress == 0)
        case let bar as TMBarProgressView: #expect(bar.progress == 0)
        case let native as UIProgressView: #expect(native.progress == 0)
        case let spinner as ReportingSpinnerView: #expect(spinner.progress == 0)
        default: Issue.record("Expected a recognized progress view")
        }
        hud.setContent(.custom(view))
        received.removeAll()
        hud.progress = 1
        #expect(received.isEmpty)
    }

    @Test func compatibilityAdoptionPreservesTheResolvedFunction() {
        let hud = TMProgressHud(frame: .zero)
        let spinner = ForeignSpinnerView(style: .medium)
        hud.setContent(.custom(spinner, updateProgress: { spinner.progress = Double($0) }))
        hud.mode = .indeterminate
        hud.progress = 0.75
        #expect(spinner.isAnimating)
        #expect(spinner.progress == 0.75)
        hud.setContent(.custom(spinner))
        hud.progress = 1
        #expect(spinner.progress == 0.75)
    }

    @Test func inactiveCustomContentKeepsItsFunctionUntilItsViewIsReplaced() {
        let hud = TMProgressHud(frame: .zero)
        let first = ForeignProgressView()
        hud.setContent(.custom(first, updateProgress: { first.progress = Double($0) }))
        hud.customView = first
        hud.mode = .text
        let pendingProgress: Float = 0.6
        hud.progress = pendingProgress
        #expect(first.progress == 0)
        hud.mode = .customView
        #expect(first.progress == Double(pendingProgress))
        let second = ForeignProgressView()
        hud.customView = second
        hud.progress = 0.8
        #expect(first.progress == Double(pendingProgress))
        #expect(second.received.isEmpty)
    }

    @Test func explicitFunctionReceivesRawProgressAndCanSelectOtherContent() {
        let hud = TMProgressHud(frame: .zero)
        let receiver = ProgressReceiver()
        hud.setContent(.custom(UIView(), updateProgress: { receiver.received.append($0) }))
        for value: Float in [-0.5, 1.5, .nan, .infinity] { hud.progress = value }
        #expect(receiver.received.count == 5)
        #expect(receiver.received[1] == -0.5)
        #expect(receiver.received[2] == 1.5)
        #expect(receiver.received[3].isNaN)
        #expect(receiver.received[4] == .infinity)
        hud.setContent(.custom(UIView(), updateProgress: { _ in hud.setContent(.text) }))
        #expect(hud.mode == .text)
        #expect(hud.customView == nil)
        hud.progress = 0.5
        #expect(receiver.received.count == 5)
    }

    @Test func repeatedAdoptionReleasesTheViewAndItsCapturedOwnerWhenContentChanges() {
        let hud = TMProgressHud(frame: .zero)
        weak var releasedView: TMRoundProgressView?
        weak var releasedOwner: ProgressReceiver?
        autoreleasepool {
            let view = TMRoundProgressView()
            let owner = ProgressReceiver()
            releasedView = view
            releasedOwner = owner
            hud.setContent(
                .custom(
                    view,
                    updateProgress: { [view, owner] value in
                        view.progress = value
                        owner.received.append(value)
                    }))
            let adoptionCycles = 20
            for _ in 0..<adoptionCycles {
                hud.mode = .annularDeterminate
                hud.mode = .determinate
            }
            hud.progress = 0.75
            #expect(view.progress == 0.75)
            let initialAndFinalUpdates = 2
            #expect(owner.received.count == initialAndFinalUpdates + adoptionCycles * 2)
            hud.setContent(.text)
            hud.updateConstraintsIfNeeded()
        }
        #expect(releasedView == nil)
        #expect(releasedOwner == nil)
    }

    @Test func removingTheFunctionReleasesItsCapturedOwnerWhileKeepingTheView() {
        let hud = TMProgressHud(frame: .zero)
        let view = UIView()
        weak var released: ProgressReceiver?
        autoreleasepool {
            let owner = ProgressReceiver()
            released = owner
            hud.setContent(.custom(view, updateProgress: { owner.received.append($0) }))
            hud.setContent(.custom(view))
        }
        #expect(released == nil)
        #expect(view.superview === hud.bezelView)
    }

    @Test func typedCustomContentReceivesRawProgress() {
        let hud = TMProgressHud(frame: .zero)
        let custom = TypedProgressView()
        hud.setContent(.custom(custom))
        hud.setProgressSource(.manual(1.5))
        #expect(custom.progress == 1.5)
    }

    @Test func nativeUIKitProgressBarRemainsSupported() {
        let hud = TMProgressHud(frame: .zero)
        let custom = UIProgressView(progressViewStyle: .default)
        hud.setContent(.custom(custom))
        hud.setProgressSource(.manual(0.375))
        #expect(custom.progress == 0.375)
    }
}
