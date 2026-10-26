import MBProgressHUDReference
import Testing
import UIKit
import TMProgressHudUIKit

@MainActor
private final class LayoutGetterOverride: TMProgressHud {
    override var offset: CGPoint {
        get { CGPoint(x: 12, y: -15) }
        set { super.offset = newValue }
    }
    override var margin: CGFloat {
        get { 30 }
        set { super.margin = newValue }
    }
}

@Suite(.serialized)
@MainActor
struct LayoutMigrationTests {
    @Test(arguments: [UISemanticContentAttribute.forceLeftToRight, .forceRightToLeft])
    func compatibilityEdgeOffsetsKeepTheirPhysicalPlacement(direction: UISemanticContentAttribute) {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        host.semanticContentAttribute = direction
        let hud = TMProgressHud(view: host)
        let reference = MBProgressHUD(view: host)
        host.addSubview(hud)
        host.addSubview(reference)
        hud.mode = .text
        reference.mode = .text
        hud.label.text = "Loading"
        reference.label.text = hud.label.text
        let offsets = [
            CGPoint(x: TMProgressMaxOffset, y: 0), CGPoint(x: -TMProgressMaxOffset, y: 0),
            CGPoint(x: 0, y: TMProgressMaxOffset), CGPoint(x: 0, y: -TMProgressMaxOffset),
            CGPoint(x: TMProgressMaxOffset, y: -TMProgressMaxOffset),
        ]
        for offset in offsets {
            hud.offset = offset
            reference.offset = offset
            host.layoutIfNeeded()
            #expect(hud.bezelView.frame == reference.bezelView.frame)
            #expect(hud.offset == offset)
        }
    }

    @Test(
        arguments: [TMProgressHudPosition.Horizontal.left, .center, .right],
        [TMProgressHudPosition.Vertical.top, .center, .bottom])
    func explicitPositionsAlignWithIndependentHostInsets(
        horizontal: TMProgressHudPosition.Horizontal, vertical: TMProgressHudPosition.Vertical
    ) {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let hud = TMProgressHud(view: host)
        hud.setContent(.text)
        host.addSubview(hud)
        let layout = TMProgressHudLayout(
            position: .init(horizontal: horizontal, vertical: vertical),
            contentInsets: UIEdgeInsets(top: 10, left: 12, bottom: 20, right: 28),
            hostInsets: UIEdgeInsets(top: 30, left: 40, bottom: 50, right: 60))
        hud.setLayout(layout)
        host.layoutIfNeeded()
        #expect(hud.layoutConfiguration == layout)
        #expect(hud.bezelView.bounds.size == CGSize(width: 40, height: 30))
        switch horizontal {
        case .left: #expect(hud.bezelView.frame.minX == 40)
        case .center: #expect(hud.bezelView.frame.midX == 200)
        case .right: #expect(hud.bezelView.frame.maxX == 340)
        }
        switch vertical {
        case .top: #expect(hud.bezelView.frame.minY == 30)
        case .center: #expect(hud.bezelView.frame.midY == 300)
        case .bottom: #expect(hud.bezelView.frame.maxY == 550)
        }
    }

    @Test(arguments: [UISemanticContentAttribute.forceLeftToRight, .forceRightToLeft])
    func physicalPositionAndAsymmetricContentPaddingDoNotMirror(direction: UISemanticContentAttribute) {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        host.semanticContentAttribute = direction
        let hud = TMProgressHud(view: host)
        hud.setContent(.text)
        hud.label.text = "Loading"
        host.addSubview(hud)
        hud.setLayout(
            .init(
                position: .init(horizontal: .left, vertical: .top, offset: CGPoint(x: 5, y: 7)),
                contentInsets: UIEdgeInsets(top: 10, left: 12, bottom: 20, right: 28),
                hostInsets: UIEdgeInsets(top: 30, left: 40, bottom: 50, right: 60)))
        host.layoutIfNeeded()
        expectLayoutValue(hud.bezelView.frame.minX, equals: 45)
        expectLayoutValue(hud.bezelView.frame.minY, equals: 37)
        expectLayoutValue(hud.label.frame.minX, equals: 12)
        expectLayoutValue(hud.bezelView.bounds.maxX - hud.label.frame.maxX, equals: 28)
        expectLayoutValue(hud.label.frame.minY, equals: 10)
        expectLayoutValue(hud.bezelView.bounds.maxY - hud.label.frame.maxY, equals: 20)
    }

    @Test func compatibilitySettersChangeOnlyTheirDocumentedPartOfTheSelection() {
        let hud = TMProgressHud(frame: .zero)
        let layout = TMProgressHudLayout(
            position: .init(horizontal: .right, vertical: .bottom, offset: CGPoint(x: -5, y: -7)),
            contentInsets: UIEdgeInsets(top: 10, left: 12, bottom: 20, right: 28),
            hostInsets: UIEdgeInsets(top: 30, left: 40, bottom: 50, right: 60))
        hud.setLayout(layout)
        let projection = hud.offset
        #expect(projection == CGPoint(x: TMProgressMaxOffset, y: TMProgressMaxOffset))
        hud.offset = projection
        #expect(hud.layoutConfiguration == layout)
        hud.offset = CGPoint(x: 8, y: -12)
        #expect(hud.layoutConfiguration.position == .init(offset: CGPoint(x: 8, y: -12)))
        #expect(hud.layoutConfiguration.contentInsets == layout.contentInsets)
        #expect(hud.layoutConfiguration.hostInsets == layout.hostInsets)
        #expect(hud.margin == 10)
        hud.margin = 10  // Even the same top value explicitly restores uniform spacing.
        hud.margin = 10
        let uniform = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        #expect(hud.layoutConfiguration.contentInsets == uniform)
        #expect(hud.layoutConfiguration.hostInsets == uniform)
    }

    @Test func hostBoundsAndClientConstraintsSurviveExplicitPositionChanges() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let hud = TMProgressHud(view: host)
        hud.setContent(.text)
        host.addSubview(hud)
        let client = hud.bezelView.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
        client.isActive = true
        let layout = TMProgressHudLayout(position: .init(horizontal: .right, vertical: .bottom))
        hud.setLayout(layout)
        host.layoutIfNeeded()
        #expect(client.isActive)
        expectLayoutValue(hud.bezelView.frame.maxX, equals: 380)
        expectLayoutValue(hud.bezelView.frame.maxY, equals: 580)
        host.bounds.size = CGSize(width: 500, height: 700)
        host.layoutIfNeeded()
        expectLayoutValue(hud.bezelView.frame.maxX, equals: 480)
        expectLayoutValue(hud.bezelView.frame.maxY, equals: 680)
        hud.setLayout(.init(position: .init(offset: CGPoint(x: 10_000, y: -10_000))))
        host.layoutIfNeeded()
        hud.setNeedsLayout()
        hud.layoutIfNeeded()
        expectLayoutValue(hud.bezelView.frame.maxX, equals: 480)
        expectLayoutValue(hud.bezelView.frame.minY, equals: 20)
        #expect(client.isActive)
    }

    @Test func layoutObserversSeeTheCompletedSelectionAndEqualSelectionIsANoOp() {
        let hud = TMProgressHud(frame: .zero)
        let layout = TMProgressHudLayout(
            position: .init(horizontal: .left, vertical: .top),
            contentInsets: UIEdgeInsets(top: 10, left: 12, bottom: 20, right: 28),
            hostInsets: UIEdgeInsets(top: 30, left: 40, bottom: 50, right: 60))
        let recorder = HUDChangeRecorder()
        let offset = recorder.observe(hud, \.offset) { observed in
            #expect(observed.layoutConfiguration == layout)
            #expect(observed.margin == 10)
        }
        let margin = recorder.observe(hud, \.margin) { observed in
            #expect(observed.layoutConfiguration == layout)
            #expect(observed.offset == CGPoint(x: -TMProgressMaxOffset, y: -TMProgressMaxOffset))
        }
        defer { offset.invalidate(); margin.invalidate() }
        hud.setLayout(layout)
        #expect(recorder.count == 2)
        hud.setLayout(layout)
        #expect(recorder.count == 2)
    }

    @Test func visibleHUDSwitchesAnchorsDuringWindowLayout() throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.setContent(.text)
        hud.label.text = "Loading"
        hud.setLayout(.init(position: .init(horizontal: .right, vertical: .bottom)))
        window.layoutIfNeeded()
        expectLayoutValue(hud.bezelView.frame.maxX, equals: host.bounds.maxX - 20)
        expectLayoutValue(hud.bezelView.frame.maxY, equals: host.bounds.maxY - 20)
        hud.setLayout(.init(position: .init(horizontal: .left, vertical: .top)))
        window.layoutIfNeeded()
        expectLayoutValue(hud.bezelView.frame.minX, equals: 20)
        expectLayoutValue(hud.bezelView.frame.minY, equals: 20)
    }

    @Test func layoutValuesCrossTaskBoundaries() async {
        let layout = await Task.detached {
            TMProgressHudLayout(position: .init(horizontal: .left, vertical: .bottom))
        }.value
        let hud = TMProgressHud(frame: .zero)
        hud.setLayout(layout)
        #expect(hud.layoutConfiguration == layout)
    }

    @Test func layoutRespectsOverriddenCompatibilityGetters() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let hud = LayoutGetterOverride(view: host)
        hud.setContent(.text)
        host.addSubview(hud)
        host.layoutIfNeeded()
        expectLayoutValue(hud.bezelView.frame.midX, equals: 212)
        expectLayoutValue(hud.bezelView.frame.midY, equals: 285)
        #expect(hud.bezelView.bounds.size == CGSize(width: 60, height: 60))
        hud.setLayout(
            .init(
                position: .init(horizontal: .right, vertical: .bottom),
                contentInsets: .zero, hostInsets: .zero))
        host.layoutIfNeeded()
        hud.setNeedsLayout()
        hud.layoutIfNeeded()
        expectLayoutValue(hud.bezelView.frame.midX, equals: 212)
        expectLayoutValue(hud.bezelView.frame.midY, equals: 285)
        #expect(hud.bezelView.bounds.size == CGSize(width: 60, height: 60))
    }
    private func expectLayoutValue(_ actual: CGFloat, equals expected: CGFloat) {
        // Auto Layout's floating-point solver may leave subpixel arithmetic residue.
        let solverPrecisionInPoints: CGFloat = 0.001
        #expect(abs(actual - expected) <= solverPrecisionInPoints)
    }

}
