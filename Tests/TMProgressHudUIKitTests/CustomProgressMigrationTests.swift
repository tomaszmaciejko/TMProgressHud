import Testing
import UIKit
import TMProgressHudUIKit

@MainActor
private final class LegacyProgressView: UIView {
    @objc dynamic var progress: Float = 0 {
        didSet { received.append(progress) }
    }
    private(set) var received: [Float] = []
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
private final class LegacySpinnerView: UIActivityIndicatorView {
    @objc dynamic var progress: Float = 0
}

@Suite(.serialized)
@MainActor
struct CustomProgressMigrationTests {
    @Test(arguments: [false, true])
    func spinnerSubclassReceivesItsDeclaredProgressAndKeepsSpinnerColoring(useLegacySelection: Bool) {
        let hud = TMProgressHud(frame: .zero)
        let spinner = ReportingSpinnerView(style: .medium)
        hud.progress = 0.25
        hud.setContent(useLegacySelection ? .legacyCustom(spinner) : .custom(spinner))
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

    @Test func compatibilityReuseKeepsTheSpinnersLegacyProgressContract() {
        let hud = TMProgressHud(frame: .zero)
        let spinner = LegacySpinnerView(style: .medium)
        hud.customView = spinner
        hud.mode = .customView
        hud.progress = 0.25
        #expect(spinner.progress == 0.25)
        hud.mode = .indeterminate
        #expect(spinner.isAnimating)
        hud.progress = 0.75
        #expect(spinner.progress == 0.75)
        hud.setContent(.activity)
        #expect(spinner.superview == nil)
        hud.progress = 1
        #expect(spinner.progress == 0.75)
    }

    @Test func customContentDoesNotGuessAnObjectiveCProgressContract() {
        let hud = TMProgressHud(frame: .zero)
        let custom = LegacyProgressView()
        hud.setContent(.custom(custom))
        hud.setProgressSource(.manual(0.4))
        #expect(custom.received.isEmpty)
    }

    @Test func explicitLegacySelectionChangesOnlyTheProgressContract() {
        let hud = TMProgressHud(frame: .zero)
        let custom = LegacyProgressView()
        hud.setContent(.custom(custom))
        hud.setProgressSource(.manual(0.4))
        #expect(custom.received.isEmpty)
        hud.setContent(.legacyCustom(custom))
        #expect(custom.received == [0.4])
        #expect(hud.mode == .customView)
        #expect(hud.customView === custom)
        hud.setContent(.legacyCustom(custom))
        #expect(custom.received == [0.4])
        hud.progress = 0.7
        #expect(custom.received == [0.4, 0.7])
        hud.setContent(.custom(custom))
        hud.progress = 0.2
        #expect(custom.received == [0.4, 0.7])
    }

    @Test func compatibilityPropertiesRetainAutomaticLegacyProgress() {
        let hud = TMProgressHud(frame: .zero)
        let first = LegacyProgressView()
        hud.customView = first
        hud.mode = .customView
        hud.progress = 0.6
        #expect(first.progress == 0.6)
        hud.setContent(.custom(first))
        let second = LegacyProgressView()
        hud.customView = second
        #expect(second.progress == 0.6)
        hud.progress = 0.8
        #expect(second.progress == 0.8)
        hud.mode = .text
        hud.mode = .customView
        #expect(second.progress == 0.8)
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
