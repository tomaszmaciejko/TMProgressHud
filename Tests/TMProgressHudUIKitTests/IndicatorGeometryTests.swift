import Testing
import UIKit
import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct IndicatorGeometryTests {
    @Test func drawingUsesBoundedFiniteProgress() throws {
        let pie = TMRoundProgressView()
        let ring = TMRoundProgressView()
        ring.isAnnular = true
        for view in [pie, ring] {
            let cases: [(Float, Float)] = [(-1, 0), (2, 1), (.nan, 0), (.infinity, 0), (-.infinity, 0)]
            for (input, expected) in cases {
                view.progress = input
                let actual = try pixels(view)
                view.progress = expected
                #expect(actual == (try pixels(view)))
            }
        }
    }

    @Test(arguments: [false, true])
    func circularDrawingFitsAndCentersInRectangularBounds(annular: Bool) throws {
        let square = TMRoundProgressView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        square.isAnnular = annular
        square.progress = 0.6
        for size in [CGSize(width: 80, height: 40), CGSize(width: 40, height: 80)] {
            let rectangle = TMRoundProgressView(frame: CGRect(origin: .zero, size: size))
            rectangle.isAnnular = annular
            rectangle.progress = square.progress
            let offset = CGPoint(x: (size.width - 40) / 2, y: (size.height - 40) / 2)
            #expect(try pixels(rectangle) == pixels(square, canvas: size, offset: offset))
            rectangle.bounds.origin = CGPoint(x: 17, y: 9)
            #expect(try pixels(rectangle) == pixels(square, canvas: size, offset: offset))
        }
    }

    @Test(arguments: [false, true])
    func undersizedCirclesDrawNothing(annular: Bool) throws {
        let view = TMRoundProgressView(frame: CGRect(x: 0, y: 0, width: 1, height: 10))
        view.isAnnular = annular
        view.progress = 0.5
        #expect(try pixels(view).allSatisfy { $0 == 0 })
    }

    private func pixels(_ view: UIView, canvas: CGSize? = nil, offset: CGPoint = .zero) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: canvas ?? view.bounds.size, format: format).image { context in
            context.cgContext.translateBy(x: offset.x - view.bounds.minX, y: offset.y - view.bounds.minY)
            view.draw(view.bounds)
        }
        return try #require(image.cgImage?.dataProvider?.data) as Data
    }
}
