import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class CountingBackgroundView: TMBackgroundView {
    private(set) var insertedEffectCount = 0

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        if subview is UIVisualEffectView { insertedEffectCount += 1 }
    }
}

@Suite(.serialized)
@MainActor
struct BackgroundViewTests {
    @Test func solidBackgroundDoesNotCreateATransientEffect() {
        let background = CountingBackgroundView(frame: .zero, style: .solidColor, blurPolicy: .configured)
        #expect(background.insertedEffectCount == 0)
        #expect(background.subviews.isEmpty)
        background.blurEffectStyle = .dark
        #expect(background.insertedEffectCount == 0)
        background.style = .blur
        #expect(background.insertedEffectCount == 1)
    }

    @Test func changingMaterialReusesTheEffectView() throws {
        let background = CountingBackgroundView(frame: CGRect(x: 0, y: 0, width: 100, height: 80))
        background.blurPolicy = .configured
        let initial = try #require(background.subviews.compactMap { $0 as? UIVisualEffectView }.first)
        #expect(background.insertedEffectCount == 1)
        for material in [UIBlurEffect.Style.dark, .regular] {
            background.blurEffectStyle = material
            #expect(background.subviews.first === initial)
            #expect(background.insertedEffectCount == 1)
        }
        background.frame.size = CGSize(width: 140, height: 120)
        background.layoutIfNeeded()
        #expect(initial.frame == background.bounds)
    }

    @Test func changingBackgroundStylePreservesCallerSubviews() throws {
        let background = CountingBackgroundView(frame: .zero)
        background.blurPolicy = .configured
        let initial = try #require(background.subviews.first)
        let custom = UIView()
        background.addSubview(custom)
        background.style = .solidColor
        #expect(background.subviews == [custom])
        #expect(initial.superview == nil)
        background.blurEffectStyle = .dark
        #expect(background.insertedEffectCount == 1)
        background.style = .blur
        #expect(background.insertedEffectCount == 2)
        #expect(background.subviews.last === custom)
        #expect(background.subviews.first !== initial)
    }
}
