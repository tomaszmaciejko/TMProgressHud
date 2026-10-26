import Foundation
import Testing
import UIKit
@testable import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct TraitAppearanceTests {
    enum IndicatorStyle: CaseIterable {
        case bar, pie, ring

        @MainActor func makeView() -> UIView {
            switch self {
            case .bar: return TMBarProgressView()
            case .pie: return TMRoundProgressView()
            case .ring:
                let view = TMRoundProgressView()
                view.isAnnular = true
                return view
            }
        }
    }

    @Test(arguments: IndicatorStyle.allCases, [false, true])
    func indicatorsRequestRedrawWhenColorAppearanceChanges(style: IndicatorStyle, decoded: Bool) throws {
        let original = style.makeView()
        let view = try decoded ? archiveRoundTrip(original) : original
        view.traitOverrides.userInterfaceStyle = .light
        view.traitOverrides.accessibilityContrast = .normal
        view.updateTraitsIfNeeded()
        view.layer.displayIfNeeded()
        #expect(!view.layer.needsDisplay())

        view.traitOverrides.userInterfaceStyle = .dark
        view.updateTraitsIfNeeded()
        #expect(view.layer.needsDisplay())
        view.layer.displayIfNeeded()
        #expect(!view.layer.needsDisplay())

        view.traitOverrides.accessibilityContrast = .high
        view.updateTraitsIfNeeded()
        #expect(view.layer.needsDisplay())
    }

    @Test(arguments: [false, true])
    func buttonBorderFollowsItsOwnAppearanceTraits(decoded: Bool) throws {
        let original = HUDRoundedButtonView(frame: .zero)
        original.setTitleColor(.blue, for: .normal)
        #expect(original.layer.borderColor == UIColor.blue.cgColor)
        let button = try decoded ? archiveRoundTrip(original) : original
        #expect(button.titleColor(for: .normal) == UIColor.blue)
        button.traitOverrides.userInterfaceStyle = .dark
        button.traitOverrides.accessibilityContrast = .normal
        button.updateTraitsIfNeeded()
        let color = adaptiveColor()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            button.setTitleColor(color, for: .normal)
        }
        #expect(button.layer.borderColor == UIColor.white.cgColor)

        button.traitOverrides.userInterfaceStyle = .light
        button.updateTraitsIfNeeded()
        #expect(button.layer.borderColor == UIColor.black.cgColor)

        button.traitOverrides.accessibilityContrast = .high
        button.updateTraitsIfNeeded()
        #expect(button.layer.borderColor == UIColor.red.cgColor)
        #expect(button.titleColor(for: .normal) === color)
    }

    @Test func decodedButtonPreservesArchivedBorderAcrossAppearanceChanges() throws {
        let button = try archiveRoundTrip(HUDRoundedButtonView(frame: .zero))
        let archivedBorder = button.layer.borderColor
        button.traitOverrides.userInterfaceStyle = .light
        button.updateTraitsIfNeeded()
        button.traitOverrides.userInterfaceStyle = .dark
        button.updateTraitsIfNeeded()
        #expect(button.layer.borderColor == archivedBorder)
    }

    @Test func buttonBorderUsesLatestAssignedColorAndCanBeCleared() {
        let button = HUDRoundedButtonView(frame: .zero)
        button.traitOverrides.userInterfaceStyle = .light
        button.updateTraitsIfNeeded()
        button.setTitleColor(.green, for: .normal)
        button.setTitleColor(adaptiveColor(), for: .selected)
        button.traitOverrides.userInterfaceStyle = .dark
        button.updateTraitsIfNeeded()
        #expect(button.layer.borderColor == UIColor.white.cgColor)

        button.setTitleColor(nil, for: .normal)
        button.traitOverrides.accessibilityContrast = .high
        button.updateTraitsIfNeeded()
        #expect(button.layer.borderColor == nil)

        button.setTitleColor(.blue, for: .normal)
        button.traitOverrides.userInterfaceStyle = .light
        button.updateTraitsIfNeeded()
        #expect(button.layer.borderColor == UIColor.blue.cgColor)
    }

    @Test func appearanceRegistrationsDoNotRetainViews() {
        weak var button: HUDRoundedButtonView?
        weak var bar: TMBarProgressView?
        weak var round: TMRoundProgressView?
        autoreleasepool {
            let createdButton = HUDRoundedButtonView(frame: .zero)
            createdButton.setTitleColor(adaptiveColor(), for: .normal)
            button = createdButton
            let createdBar = TMBarProgressView()
            let createdRound = TMRoundProgressView()
            bar = createdBar
            round = createdRound
            #expect(button != nil && bar != nil && round != nil)
        }
        #expect(button == nil)
        #expect(bar == nil)
        #expect(round == nil)
    }

    private func adaptiveColor() -> UIColor {
        UIColor { traits in
            if traits.accessibilityContrast == .high { return .red }
            return traits.userInterfaceStyle == .dark ? .white : .black
        }
    }
}
