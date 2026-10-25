import MBProgressHUDReference
import Testing
import UIKit
@testable import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct IndicatorTests {
    @Test func defaultsAndUnnormalizedProgressMatchReference() {
        let round = TMRoundProgressView()
        let bar = TMBarProgressView()
        #expect(round.frame.size == CGSize(width: 37, height: 37))
        #expect(round.intrinsicContentSize == MBRoundProgressView().intrinsicContentSize)
        #expect(bar.frame.size == CGSize(width: 120, height: 20))
        #expect(bar.intrinsicContentSize == MBBarProgressView().intrinsicContentSize)
        #expect(!round.isAnnular)
        #expect(round.backgroundTintColor == MBRoundProgressView().backgroundTintColor)
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
