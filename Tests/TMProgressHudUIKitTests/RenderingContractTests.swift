import MBProgressHUDReference
import Testing
import UIKit
import TMProgressHudUIKit

@MainActor
private final class ReferenceRoundGetterOverride: MBRoundProgressView {
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
private final class RoundGetterOverride: TMRoundProgressView {
    override var isAnnular: Bool {
        get { true }
        set { super.isAnnular = newValue }
    }
    override var progressTintColor: UIColor {
        get { .red }
        set { super.progressTintColor = newValue }
    }
    override var backgroundTintColor: UIColor {
        get { .blue }
        set { super.backgroundTintColor = newValue }
    }
}

@MainActor
private final class ReferenceBarGetterOverride: MBBarProgressView {
    override var lineColor: UIColor {
        get { .red }
        set { super.lineColor = newValue }
    }
}

@MainActor
private final class BarGetterOverride: TMBarProgressView {
    override var lineColor: UIColor {
        get { .red }
        set { super.lineColor = newValue }
    }
    override var progressColor: UIColor {
        get { .green }
        set { super.progressColor = newValue }
    }
    override var progressRemainingColor: UIColor {
        get { .blue }
        set { super.progressRemainingColor = newValue }
    }
}

@Suite(.serialized)
@MainActor
struct RenderingContractTests {
    @Test func roundDrawingPreservesShapeAtNativePrecision() throws {
        for size: CGFloat in [37, 123, 512] {
            for annular in [false, true] {
                for progress: Float in [0.1234567, 0.3333333, 0.731, 0.876543] {
                    let rect = CGRect(x: 0, y: 0, width: size, height: size)
                    let original = MBRoundProgressView(frame: rect)
                    let port = TMRoundProgressView(frame: rect)
                    original.isAnnular = annular
                    port.isAnnular = annular
                    original.progress = progress
                    port.progress = progress
                    original.progressTintColor = UIColor.red.withAlphaComponent(0.37)
                    port.progressTintColor = original.progressTintColor
                    let actual = try pixels(port)
                    let expected = try pixels(original)
                    let difference = try rasterDifference(actual, expected)
                    if size == 37 {
                        #expect(actual == expected)
                    } else {
                        // Native angles may change sparse antialiasing samples at enlarged sizes.
                        // Allow one quantization step per raster, in at most one byte per 100,000.
                        let maximumChannelDifference = 2
                        let maximumChangedFraction = 0.00001
                        #expect(difference.maximum <= maximumChannelDifference)
                        #expect(Double(difference.changed) / Double(actual.count) <= maximumChangedFraction)
                    }
                }
            }
        }
    }

    @Test func indicatorDrawingHonorsOverriddenGetters() throws {
        let portRound = RoundGetterOverride()
        let originalRound = ReferenceRoundGetterOverride()
        let expectedRound = TMRoundProgressView()
        for view in [portRound, expectedRound] { view.progress = 0.5 }
        originalRound.progress = 0.5
        expectedRound.isAnnular = true
        expectedRound.progressTintColor = .red
        expectedRound.backgroundTintColor = .blue
        #expect(try pixels(portRound) == pixels(expectedRound))
        #expect(try pixels(portRound) != pixels(originalRound))
        let portBar = BarGetterOverride()
        let originalBar = ReferenceBarGetterOverride()
        let expectedBar = TMBarProgressView()
        for view in [portBar, expectedBar] { view.progress = 0.5 }
        originalBar.progress = 0.5
        expectedBar.lineColor = .red
        expectedBar.progressColor = .green
        expectedBar.progressRemainingColor = .blue
        #expect(try pixels(portBar) == pixels(expectedBar))
        #expect(try pixels(portBar) != pixels(originalBar))
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

    @Test(arguments: [Float(0), 0.01, 0.5, 0.99, 1, 2])
    func barPartialDrawingMatchesFullDrawing(progress: Float) throws {
        let bar = TMBarProgressView(frame: CGRect(x: 0, y: 0, width: 120, height: 20))
        bar.progress = progress
        let region = CGRect(x: 40, y: 0, width: 40, height: 20)
        let full = try pixels(bar, clippingRect: region)
        let partial = try pixels(bar, drawingRect: region, clippingRect: region)
        #expect(partial == full)
    }

    @Test func barDrawingUsesItsBoundsOrigin() throws {
        let bar = TMBarProgressView(frame: CGRect(x: 0, y: 0, width: 120, height: 20))
        bar.progress = 0.5
        let original = try pixels(bar)
        bar.bounds.origin = CGPoint(x: 17, y: 9)
        #expect(try pixels(bar) == original)
    }

    private func rasterDifference(_ actual: Data, _ expected: Data) throws -> (maximum: Int, changed: Int) {
        try #require(actual.count == expected.count)
        return actual.withUnsafeBytes { actualBytes in
            expected.withUnsafeBytes { expectedBytes in
                var maximum = 0
                var changed = 0
                for index in 0..<actualBytes.count {
                    let difference = abs(Int(actualBytes[index]) - Int(expectedBytes[index]))
                    maximum = max(maximum, difference)
                    if difference != 0 { changed += 1 }
                }
                return (maximum, changed)
            }
        }
    }

    private func pixels(
        _ view: UIView, fillAfterDrawing: Bool = false,
        drawingRect: CGRect? = nil, clippingRect: CGRect? = nil
    ) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { context in
            context.cgContext.translateBy(x: -view.bounds.minX, y: -view.bounds.minY)
            context.cgContext.clip(to: clippingRect ?? view.bounds)
            view.draw(drawingRect ?? view.bounds)
            if fillAfterDrawing { context.cgContext.fill(view.bounds) }
        }
        return try #require(image.cgImage?.dataProvider?.data) as Data
    }
}
