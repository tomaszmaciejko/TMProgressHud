import MBProgressHUDReference
import Testing
import UIKit
import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct IndicatorTests {
    @Test func defaultsAndUnnormalizedProgressHaveStableValues() {
        let round = TMRoundProgressView()
        let bar = TMBarProgressView()
        #expect(round.frame.size == CGSize(width: 37, height: 37))
        #expect(round.intrinsicContentSize == MBRoundProgressView().intrinsicContentSize)
        #expect(bar.frame.size == CGSize(width: 120, height: 20))
        #expect(bar.intrinsicContentSize == MBBarProgressView().intrinsicContentSize)
        #expect(!round.isAnnular)
        #expect(round.backgroundTintColor == UIColor(white: 1, alpha: 0.1))
        for value: Float in [-1, 0, 0.5, 1, 2, .infinity, -.infinity] {
            round.progress = value
            bar.progress = value
            #expect(round.progress == value)
            #expect(bar.progress == value)
        }
        round.progress = .nan
        bar.progress = .nan
        #expect(round.progress.isNaN)
        #expect(bar.progress.isNaN)
    }

    @Test(arguments: [false, true], [Float(0), 0.25, 0.5, 1])
    func roundDrawingMatchesOriginal(annular: Bool, progress: Float) throws {
        let reference = MBRoundProgressView()
        let port = TMRoundProgressView()
        reference.isAnnular = annular
        port.isAnnular = annular
        reference.progress = progress
        port.progress = progress
        reference.progressTintColor = .red
        port.progressTintColor = .red
        reference.backgroundTintColor = .blue
        port.backgroundTintColor = .blue
        #expect(try pixels(reference) == pixels(port))
        port.draw(port.bounds)  // Drawing without a graphics context is a defined no-op.
    }

    @Test(arguments: [Float(0), 0.01, 0.5, 0.99, 1, 2])
    func barDrawingMatchesOriginal(progress: Float) throws {
        let reference = MBBarProgressView()
        let port = TMBarProgressView()
        reference.progress = progress
        port.progress = progress
        reference.progressColor = .red
        port.progressColor = .red
        reference.progressRemainingColor = .blue
        port.progressRemainingColor = .blue
        reference.lineColor = .green
        port.lineColor = .green
        #expect(try pixels(reference) == pixels(port))
        port.draw(port.bounds)
    }

    @Test func colorSettersAndBackgroundChangesAreReversible() {
        let round = TMRoundProgressView(frame: .zero)
        round.progressTintColor = .red
        round.progressTintColor = .red
        round.backgroundTintColor = .blue
        round.backgroundTintColor = .blue
        let bar = TMBarProgressView(frame: .zero)
        bar.progressColor = .red
        bar.progressColor = .red
        bar.progressRemainingColor = .blue
        bar.progressRemainingColor = .blue
        let background = TMBackgroundView(frame: CGRect(x: 0, y: 0, width: 100, height: 80))
        #expect(background.subviews.count == 1)
        #expect(background.intrinsicContentSize == .zero)
        background.style = .solidColor
        #expect(background.subviews.isEmpty)
        background.style = .solidColor
        background.color = .red
        background.color = .red
        #expect(background.backgroundColor == .red)
        background.style = .blur
        background.blurEffectStyle = .dark
        background.blurEffectStyle = .dark
        #expect(background.subviews.count == 1)
        background.color = nil
        #expect(background.backgroundColor == nil)
    }

    @Test func enumCasesPreserveRawValues() {
        for (index, mode) in [
            TMProgressHudMode.indeterminate, .determinate, .determinateHorizontalBar,
            .annularDeterminate, .customView, .text,
        ].enumerated() {
            #expect(mode.rawValue == index)
            #expect(TMProgressHudMode(rawValue: index) == mode)
        }
        for (index, animation) in [TMProgressHudAnimation.fade, .zoom, .zoomOut, .zoomIn].enumerated() {
            #expect(animation.rawValue == index)
            #expect(TMProgressHudAnimation(rawValue: index) == animation)
        }
        #expect(TMProgressHudBackgroundStyle.solidColor.rawValue == 0)
        #expect(TMProgressHudBackgroundStyle.blur.rawValue == 1)
        #expect(TMProgressMaxOffset == MBProgressMaxOffset)
    }

    @Test func defaultColorsUseDocumentedCGFloatAlphas() {
        let hud = TMProgressHud(frame: .zero)
        #expect(hud.contentColor == UIColor.label.withAlphaComponent(0.7))
        let round = TMRoundProgressView()
        #expect(round.backgroundTintColor == UIColor(white: 1, alpha: 0.1))
        hud.button.setTitleColor(.green, for: .highlighted)
        hud.button.isHighlighted = true
        #expect(hud.button.backgroundColor == UIColor.green.withAlphaComponent(0.1))
    }

    @Test func appearanceValuesCanCrossTaskBoundaries() async {
        let values = await Task.detached {
            (TMProgressHudMode.determinate, TMProgressHudAnimation.zoomIn, TMProgressHudBackgroundStyle.solidColor)
        }.value
        #expect(values.0 == .determinate)
        #expect(values.1 == .zoomIn)
        #expect(values.2 == .solidColor)
        let hud = TMProgressHud(frame: .zero)
        hud.mode = values.0
        hud.animationType = values.1
        hud.bezelView.style = values.2
        #expect(hud.mode == .determinate)
        #expect(hud.animationType == .zoomIn)
        #expect(hud.bezelView.style == .solidColor)
    }

    private func pixels(_ view: UIView) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size, format: format)
        let image = renderer.image { _ in view.draw(view.bounds) }
        let cgImage = try #require(image.cgImage)
        let data = try #require(cgImage.dataProvider?.data)
        return data as Data
    }
}
