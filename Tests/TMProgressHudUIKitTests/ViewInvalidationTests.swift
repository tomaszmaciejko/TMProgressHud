import Testing
import UIKit
import TMProgressHudUIKit

@MainActor
private final class RoundInvalidationSpy: TMRoundProgressView {
    private(set) var redrawRequests = 0

    override func setNeedsDisplay() {
        redrawRequests += 1
        super.setNeedsDisplay()
    }
}

@MainActor
private final class BarInvalidationSpy: TMBarProgressView {
    private(set) var redrawRequests = 0

    override func setNeedsDisplay() {
        redrawRequests += 1
        super.setNeedsDisplay()
    }
}

@Suite(.serialized)
@MainActor
struct ViewInvalidationTests {
    @Test func changingRoundStyleRequestsRedrawOnlyWhenNeeded() {
        let round = RoundInvalidationSpy()
        let initial = round.redrawRequests
        round.isAnnular = true
        #expect(round.redrawRequests == initial + 1)
        round.isAnnular = true
        #expect(round.redrawRequests == initial + 1)
        round.isAnnular = false
        #expect(round.redrawRequests == initial + 2)
    }

    @Test func changingBarBorderRequestsRedrawAndPreservesAssignedColorIdentity() {
        let bar = BarInvalidationSpy()
        let initial = bar.redrawRequests
        let first = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        let equal = UIColor(cgColor: first.cgColor)
        #expect(first == equal)
        bar.lineColor = first
        #expect(bar.redrawRequests == initial + 1)
        bar.lineColor = equal
        #expect(bar.lineColor === equal)
        #expect(bar.redrawRequests == initial + 1)
        bar.lineColor = .orange
        #expect(bar.redrawRequests == initial + 2)
    }
}
