import MBProgressHUDReference
import ObjectiveC
import Testing
import UIKit
import os
import TMProgressHudUIKit

@MainActor
private final class ReferenceFrameInitializerSpy: MBProgressHUD {
    var didInitializeFrame = false
    override init(frame: CGRect) {
        super.init(frame: frame)
        didInitializeFrame = true
    }
    // The Objective-C initializer imports as designated. Provide its Swift entry point
    // so the inherited Objective-C factory does not hit Swift's unimplemented-init stub.
    override init(view: UIView) { super.init(view: view) }
    required init?(coder: NSCoder) { super.init(coder: coder) }
}

@MainActor
private final class HUDFrameInitializerSpy: TMProgressHud {
    var didInitializeFrame = false
    required init(frame: CGRect) {
        super.init(frame: frame)
        didInitializeFrame = true
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
}

@Suite(.serialized)
@MainActor
struct ObjectiveCInteropTests {
    @Test func objectiveCSelectorsArePreserved() {
        for selector in ["showHUDAddedTo:animated:", "hideHUDForView:animated:", "HUDForView:"] {
            #expect(class_getClassMethod(TMProgressHud.self, NSSelectorFromString(selector)) != nil)
            #expect(class_getClassMethod(MBProgressHUD.self, NSSelectorFromString(selector)) != nil)
        }
        let original = MBProgressHUD(view: UIView())
        let port = TMProgressHud(view: UIView())
        for selector in [
            "setSquare:", "setDefaultMotionEffectsEnabled:", "setCompletionBlock:", "completionBlock", "showAnimated:",
            "hideAnimated:", "hideAnimated:afterDelay:", "initWithView:",
        ] {
            #expect(
                port.responds(to: NSSelectorFromString(selector))
                    == original.responds(to: NSSelectorFromString(selector)), "Selector: \(selector)")
        }
        #expect(
            TMRoundProgressView().responds(to: NSSelectorFromString("setAnnular:"))
                == MBRoundProgressView().responds(to: NSSelectorFromString("setAnnular:")))
    }

    @Test func equalColorsKeepReferenceIdentity() {
        let first = UIColor(red: 0.123, green: 0.456, blue: 0.789, alpha: 1)
        let second = UIColor(red: 0.123, green: 0.456, blue: 0.789, alpha: 1)
        #expect(first == second)
        #expect(first !== second)
        let original = MBProgressHUD(view: UIView())
        let port = TMProgressHud(view: UIView())
        original.contentColor = first
        port.contentColor = first
        original.contentColor = second
        port.contentColor = second
        #expect(original.contentColor === first)
        #expect(port.contentColor === first)
    }

    @Test func indicatorAndBackgroundColorsKeepReferenceIdentity() {
        let first = UIColor(red: 0.123, green: 0.456, blue: 0.789, alpha: 1)
        let second = UIColor(red: 0.123, green: 0.456, blue: 0.789, alpha: 1)
        let round = TMRoundProgressView()
        let originalRound = MBRoundProgressView()
        let bar = TMBarProgressView()
        let originalBar = MBBarProgressView()
        let background = TMBackgroundView()
        let originalBackground = MBBackgroundView()
        for color in [first, second] {
            round.progressTintColor = color
            originalRound.progressTintColor = color
            round.backgroundTintColor = color
            originalRound.backgroundTintColor = color
            bar.progressColor = color
            originalBar.progressColor = color
            bar.progressRemainingColor = color
            originalBar.progressRemainingColor = color
            background.color = color
            originalBackground.color = color
        }
        #expect(round.progressTintColor === first)
        #expect(originalRound.progressTintColor === first)
        #expect(round.backgroundTintColor === first)
        #expect(originalRound.backgroundTintColor === first)
        #expect(bar.progressColor === first)
        #expect(originalBar.progressColor === first)
        #expect(bar.progressRemainingColor === first)
        #expect(originalBar.progressRemainingColor === first)
        #expect(background.color === first)
        #expect(originalBackground.color === first)
    }

    @Test func legacyBooleanKeysRemainUsableFromKVC() {
        let port = TMProgressHud(frame: .zero)
        let original = MBProgressHUD(frame: .zero)
        for value in [true, false] {
            port.setValue(value, forKey: "square")
            original.setValue(value, forKey: "square")
            port.setValue(value, forKey: "defaultMotionEffectsEnabled")
            original.setValue(value, forKey: "defaultMotionEffectsEnabled")
            #expect(port.isSquare == original.isSquare)
            #expect(port.areDefaultMotionEffectsEnabled == original.areDefaultMotionEffectsEnabled)
        }
        let round = TMRoundProgressView()
        let originalRound = MBRoundProgressView()
        round.setValue(true, forKey: "annular")
        originalRound.setValue(true, forKey: "annular")
        #expect(round.isAnnular == originalRound.isAnnular)
    }

    @Test func progressKVOReceivesSwiftAssignments() {
        let original = MBProgressHUD(view: UIView())
        let port = TMProgressHud(view: UIView())
        let referenceRecorder = ProgressChangeRecorder()
        let portRecorder = ProgressChangeRecorder()
        let referenceObservation = original.observe(\.progress, options: [.new]) { _, change in
            if let value = change.newValue { referenceRecorder.append(value) }
        }
        let portObservation = port.observe(\.progress, options: [.new]) { _, change in
            if let value = change.newValue { portRecorder.append(value) }
        }
        defer {
            referenceObservation.invalidate()
            portObservation.invalidate()
        }
        for value: Float in [0.2, 0.2, 0.7] {
            original.progress = value
            port.progress = value
        }
        #expect(referenceRecorder.values == [0.2, 0.2, 0.7])
        #expect(portRecorder.values == referenceRecorder.values)
    }

    @Test func hostInitializerDispatchesThroughFrameOverride() {
        let host = UIView()
        let original = ReferenceFrameInitializerSpy.showAdded(to: host, animated: false)
        let port = HUDFrameInitializerSpy.showAdded(to: host, animated: false)
        #expect(original.didInitializeFrame)
        #expect(port.didInitializeFrame == original.didInitializeFrame)
        original.hide(animated: false)
        port.hide(animated: false)
    }

}

private final class ProgressChangeRecorder: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: [Float]())
    var values: [Float] { storage.withLock { $0 } }
    func append(_ value: Float) { storage.withLock { $0.append(value) } }
}
