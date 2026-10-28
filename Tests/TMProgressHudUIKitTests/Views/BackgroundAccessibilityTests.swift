import Foundation
import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class TransparencyPreferenceStub {
    var enabled = false
    var updated = CallbackExpectation()
}

@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct BackgroundAccessibilityTests {
    @Test(arguments: [false, true])
    func policiesResolveTheSystemSetting(systemValue: Bool) {
        #expect(TMProgressHudBlurPolicy.system.usesOpaqueBackground(systemValue: systemValue) == systemValue)
        #expect(TMProgressHudBlurPolicy.opaque.usesOpaqueBackground(systemValue: systemValue))
        #expect(!TMProgressHudBlurPolicy.configured.usesOpaqueBackground(systemValue: systemValue))
    }

    @Test func initiallyOpaqueBlurDoesNotCreateAnEffect() {
        let view = TMBackgroundView(frame: .zero, style: .blur, blurPolicy: .opaque)
        #expect(view.subviews.isEmpty)
        #expect(view.backgroundColor?.cgColor.alpha == 1)
        view.blurPolicy = .configured
        #expect(view.subviews.count == 1)
    }

    @Test func fallbackPreservesMaterialTintAndCallerSubviews() throws {
        let view = TMBackgroundView(frame: .zero)
        view.blurPolicy = .configured
        view.blurEffectStyle = .dark
        let effect = try #require(view.subviews.first as? UIVisualEffectView)
        let callerContent = UIView()
        effect.contentView.addSubview(callerContent)
        let tint = UIColor.red.withAlphaComponent(0.25)
        view.color = tint
        view.opaqueBackgroundColor = .blue.withAlphaComponent(0.2)
        view.blurPolicy = .opaque
        view.blurPolicy = .opaque
        #expect(effect.effect == nil)
        #expect(!effect.isHidden)
        #expect(callerContent.superview === effect.contentView)
        #expect(view.backgroundColor == UIColor.blue)
        #expect(view.color === tint)
        #expect(view.style == .blur)
        view.opaqueBackgroundColor = .green
        view.opaqueBackgroundColor = .green
        #expect(view.backgroundColor == UIColor.green)
        view.blurEffectStyle = .regular
        view.blurPolicy = .configured
        #expect(view.subviews.first === effect)
        #expect(effect.effect != nil)
        #expect(view.backgroundColor == tint)
        #expect(view.blurEffectStyle == .regular)
        view.style = .solidColor
        view.blurPolicy = .opaque
        #expect(view.backgroundColor == tint)
        view.color = nil
        #expect(view.backgroundColor == nil)
    }

    @Test func systemChangesUpdateAnExistingBackground() async throws {
        let view = TMBackgroundView(frame: .zero)
        let preference = TransparencyPreferenceStub()
        let center = NotificationCenter()
        view.transparencyPreference = HUDSystemPreference(
            center: center, name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            read: { preference.enabled }
        ) { [weak view] in
            view?.updateBackground()
            preference.updated.signal()
        }
        view.updateBackground()
        let effect = try #require(view.subviews.first as? UIVisualEffectView)
        preference.enabled = true
        center.post(name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        try await preference.updated.wait()
        #expect(effect.effect == nil)
        #expect(view.backgroundColor?.cgColor.alpha == 1)
        preference.updated = CallbackExpectation()
        preference.enabled = false
        center.post(name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        try await preference.updated.wait()
        #expect(effect.effect != nil)
        #expect(view.backgroundColor == nil)
    }

    @Test func observationDoesNotRetainTheBackground() {
        weak var reference: TMBackgroundView?
        autoreleasepool {
            let view = TMBackgroundView(frame: .zero)
            reference = view
        }
        #expect(reference == nil)
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark], [UIAccessibilityContrast.normal, .high])
    func defaultTextHasSufficientContrastOnTheOpaqueSurface(
        appearance: UIUserInterfaceStyle, contrast: UIAccessibilityContrast
    ) throws {
        let hud = TMProgressHud(frame: .zero)
        hud.bezelView.blurPolicy = .opaque
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = appearance
            traits.accessibilityContrast = contrast
        }
        let background = try #require(hud.bezelView.backgroundColor)
        for foreground in [hud.label.textColor, hud.detailsLabel.textColor, hud.button.currentTitleColor] {
            let foreground = try #require(foreground)
            let ratio = try contrastRatio(foreground: foreground, background: background, traits: traits)
            let minimumTextContrast = 4.5
            #expect(ratio >= minimumTextContrast)
        }
    }

    private func contrastRatio(foreground: UIColor, background: UIColor, traits: UITraitCollection) throws -> Double {
        func components(_ color: UIColor) throws -> (channels: [Double], alpha: Double) {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            try #require(color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            return ([Double(red), Double(green), Double(blue)], Double(alpha))
        }
        // WCAG relative luminance: sRGB linearization and red/green/blue weights.
        // https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
        func luminance(_ channels: [Double]) -> Double {
            let linear = channels.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return zip(linear, [0.2126, 0.7152, 0.0722]).reduce(0) { $0 + $1.0 * $1.1 }
        }
        let fg = try components(foreground)
        let bg = try components(background)
        let blended = zip(fg.channels, bg.channels).map { $0 * fg.alpha + $1 * (1 - fg.alpha) }
        let first = luminance(blended), second = luminance(bg.channels)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }
}
