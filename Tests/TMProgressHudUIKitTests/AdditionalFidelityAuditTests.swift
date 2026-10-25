import MBProgressHUDReference
import ObjectiveC
import Testing
import UIKit
import os
@testable import TMProgressHudUIKit

@MainActor
private final class AuditReferenceSubclass: MBProgressHUD {
    var frameInitializerCalled = false
    override init(frame: CGRect) {
        super.init(frame: frame)
        frameInitializerCalled = true
    }
    // The Objective-C initializer imports as designated. Provide its Swift entry point
    // so the inherited Objective-C factory does not hit Swift's unimplemented-init stub.
    override init(view: UIView) { super.init(view: view) }
    required init?(coder: NSCoder) { super.init(coder: coder) }
}

@MainActor
private final class AuditPortSubclass: TMProgressHud {
    var frameInitializerCalled = false
    required init(frame: CGRect) {
        super.init(frame: frame)
        frameInitializerCalled = true
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
}

@MainActor
private final class ReferenceRoundWithCustomGetters: MBRoundProgressView {
    override var isAnnular: Bool {
        get { true }
        set { super.isAnnular = newValue }
    }
    override var progressTintColor: UIColor {
        get { .red }
        set { super.progressTintColor = newValue }
    }
}

@MainActor
private final class PortRoundWithCustomGetters: TMRoundProgressView {
    override var isAnnular: Bool {
        get { true }
        set { super.isAnnular = newValue }
    }
    override var progressTintColor: UIColor {
        get { .red }
        set { super.progressTintColor = newValue }
    }
}

@MainActor
private final class ReferenceBarWithCustomGetter: MBBarProgressView {
    override var lineColor: UIColor {
        get { .red }
        set { super.lineColor = newValue }
    }
}

@MainActor
private final class PortBarWithCustomGetter: TMBarProgressView {
    override var lineColor: UIColor {
        get { .red }
        set { super.lineColor = newValue }
    }
}

@Suite(.serialized)
@MainActor
struct AdditionalFidelityAuditTests {
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
        let referenceRecorder = AuditKVORecorder()
        let portRecorder = AuditKVORecorder()
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
        let original = AuditReferenceSubclass.showAdded(to: host, animated: false)
        let port = AuditPortSubclass.showAdded(to: host, animated: false)
        #expect(original.frameInitializerCalled)
        #expect(port.frameInitializerCalled == original.frameInitializerCalled)
        original.hide(animated: false)
        port.hide(animated: false)
    }

    @Test func roundDrawingAcrossSizesAlphasAndFractions() throws {
        for size: CGFloat in [37, 123, 512] {
            for annular in [false, true] {
                for progress: Float in [0.1234567, 0.3333333, 0.731, 1.234567] {
                    let rect = CGRect(x: 0, y: 0, width: size, height: size)
                    let original = MBRoundProgressView(frame: rect)
                    let port = TMRoundProgressView(frame: rect)
                    original.isAnnular = annular
                    port.isAnnular = annular
                    original.progress = progress
                    port.progress = progress
                    original.progressTintColor = UIColor.red.withAlphaComponent(0.37)
                    port.progressTintColor = original.progressTintColor
                    #expect(
                        try pixels(port) == pixels(original), "size=\(size), annular=\(annular), progress=\(progress)")
                }
            }
        }
    }

    @Test func indicatorDrawingUsesStoredColorsLikeReferenceIvars() throws {
        let portRound = PortRoundWithCustomGetters()
        let originalRound = ReferenceRoundWithCustomGetters()
        portRound.progress = 0.5
        originalRound.progress = 0.5
        #expect(try pixels(portRound) == pixels(originalRound))
        let portBar = PortBarWithCustomGetter()
        let originalBar = ReferenceBarWithCustomGetter()
        #expect(try pixels(portBar) == pixels(originalBar))
    }

    @Test func circularDrawingPreservesContextFillColor() throws {
        let port = TMRoundProgressView()
        let original = MBRoundProgressView()
        for annular in [false, true] {
            port.isAnnular = annular
            original.isAnnular = annular
            port.progressTintColor = .red
            original.progressTintColor = .red
            #expect(try pixels(port, fillAfterDrawing: true) == pixels(original, fillAfterDrawing: true))
        }
    }

    @Test func layoutMatchesOriginalForLTRAndRTL() throws {
        for direction in [UISemanticContentAttribute.forceLeftToRight, .forceRightToLeft] {
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
            host.semanticContentAttribute = direction
            let original = MBProgressHUD.showAdded(to: host, animated: false)
            let port = TMProgressHud.showAdded(to: host, animated: false)
            original.label.text = "Loading a long resource"
            port.label.text = original.label.text
            original.detailsLabel.text = "Additional information"
            port.detailsLabel.text = original.detailsLabel.text
            original.offset = CGPoint(x: 100, y: -25)
            port.offset = original.offset
            host.layoutIfNeeded()
            #expect(port.bezelView.frame == original.bezelView.frame)
            #expect(port.label.frame == original.label.frame)
            original.hide(animated: false)
            port.hide(animated: false)
        }
    }

    private func pixels(_ view: UIView, fillAfterDrawing: Bool = false) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { context in
            view.draw(view.bounds)
            if fillAfterDrawing { context.cgContext.fill(view.bounds) }
        }
        return try #require(image.cgImage?.dataProvider?.data) as Data
    }
}

private final class AuditKVORecorder: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: [Float]())
    var values: [Float] { storage.withLock { $0 } }
    func append(_ value: Float) { storage.withLock { $0.append(value) } }
}
