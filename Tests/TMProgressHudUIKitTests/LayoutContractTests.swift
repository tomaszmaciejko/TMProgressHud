import Foundation
import MBProgressHUDReference
import Testing
import UIKit
import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct LayoutContractTests {
    @Test(arguments: [0, 1, 2, 3, 4, 5], [false, true])
    func preservedGeometryMatchesReference(modeRawValue: Int, detailed: Bool) throws {
        let mode = try #require(TMProgressHudMode(rawValue: modeRawValue))
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let hud = TMProgressHud(view: host)
        let reference = MBProgressHUD(view: host)
        host.addSubview(hud)
        host.addSubview(reference)
        hud.customView = customContent()
        reference.customView = customContent()
        hud.mode = mode
        reference.mode = try #require(MBProgressHUDMode(rawValue: modeRawValue))
        hud.label.text = detailed ? "Loading" : nil
        reference.label.text = hud.label.text
        hud.detailsLabel.text = detailed ? "Please wait" : nil
        reference.detailsLabel.text = hud.detailsLabel.text
        hud.offset = CGPoint(x: 8, y: -12)
        reference.offset = hud.offset
        hud.margin = 24
        reference.margin = hud.margin
        hud.minSize = detailed ? CGSize(width: 140, height: 100) : .zero
        reference.minSize = hud.minSize
        hud.isSquare = detailed
        reference.isSquare = detailed
        if detailed {
            hud.button.setTitle("Cancel", for: .normal)
            reference.button.setTitle("Cancel", for: .normal)
            hud.button.addAction(UIAction { _ in }, for: .primaryActionTriggered)
            reference.button.addAction(UIAction { _ in }, for: .primaryActionTriggered)
        }
        host.layoutIfNeeded()
        expectFrames(hud, reference)
    }

    @Test(arguments: [false, true])
    func multilineAndRightToLeftLayoutMatchesReference(narrow: Bool) {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: narrow ? 240 : 600, height: 500))
        let hud = TMProgressHud(view: host)
        let reference = MBProgressHUD(view: host)
        host.addSubview(hud)
        host.addSubview(reference)
        let details = String(repeating: "Long details ", count: 12)
        for view in [hud, reference] as [UIView] { view.semanticContentAttribute = .forceRightToLeft }
        hud.label.text = "Loading"
        reference.label.text = hud.label.text
        hud.detailsLabel.text = details
        reference.detailsLabel.text = details
        host.layoutIfNeeded()
        expectFrames(hud, reference)
    }

    @Test func layoutDoesNotKeepRemovedHUDAlive() {
        weak var reference: TMProgressHud?
        autoreleasepool {
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
            let hud = TMProgressHud.showAdded(to: host, animated: false)
            hud.label.text = "Loading"
            host.layoutIfNeeded()
            reference = hud
            hud.hide(animated: false)
        }
        #expect(reference == nil)
    }

    @Test func clientConstraintsSurviveContentAndConfigurationChanges() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.label.text = "Loading"
        host.layoutIfNeeded()
        let clientHeight = hud.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        let clientBezelHeight = hud.bezelView.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        NSLayoutConstraint.activate([clientHeight, clientBezelHeight])
        hud.margin = 24
        hud.offset = CGPoint(x: 8, y: 12)
        hud.minSize = CGSize(width: 120, height: 80)
        hud.isSquare = true
        hud.mode = .text
        host.layoutIfNeeded()
        #expect(clientHeight.isActive)
        #expect(clientBezelHeight.isActive)
    }

    @Test func parameterChangesReuseExistingConstraints() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.label.text = "Loading"
        host.layoutIfNeeded()
        let original = hud.constraints + hud.bezelView.constraints
        let originalIDs = Set(original.map(ObjectIdentifier.init))
        hud.offset = CGPoint(x: 8, y: 12)
        hud.margin = 24
        host.layoutIfNeeded()
        #expect(Set((hud.constraints + hud.bezelView.constraints).map(ObjectIdentifier.init)) == originalIDs)
        hud.minSize = CGSize(width: 140, height: 100)
        hud.isSquare = true
        host.layoutIfNeeded()
        // A detached hierarchy needs a layout pass after its deferred constraint update.
        hud.setNeedsLayout()
        hud.layoutIfNeeded()
        #expect(hud.bezelView.bounds.width >= 140)
        #expect(hud.bezelView.bounds.width == hud.bezelView.bounds.height)
        hud.minSize = .zero
        hud.isSquare = false
        host.layoutIfNeeded()
        #expect(Set((hud.constraints + hud.bezelView.constraints).map(ObjectIdentifier.init)) == originalIDs)
    }

    @Test func axesAndMinimumDimensionsUpdateIndependently() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let hud = TMProgressHud(view: host)
        hud.setContent(.text)
        host.addSubview(hud)
        let scenarios: [(offset: CGPoint, minimum: CGSize)] = [
            (CGPoint(x: 12, y: -25), CGSize(width: 140, height: 90)),
            (CGPoint(x: -18, y: 15), CGSize(width: 180, height: 90)),
            (CGPoint(x: 12, y: 15), CGSize(width: 140, height: 110)),
        ]
        for scenario in scenarios {
            hud.offset = scenario.offset
            hud.minSize = scenario.minimum
            host.layoutIfNeeded()
            hud.setNeedsLayout()
            hud.layoutIfNeeded()
            #expect(hud.bezelView.frame.midX == host.bounds.midX + scenario.offset.x)
            #expect(hud.bezelView.frame.midY == host.bounds.midY + scenario.offset.y)
            #expect(hud.bezelView.bounds.size == scenario.minimum)
        }
    }

    @Test func repeatedContentChangesMatchReference() throws {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud(view: host)
        let reference = MBProgressHUD(view: host)
        host.addSubview(hud)
        host.addSubview(reference)
        hud.label.text = "Loading"
        reference.label.text = hud.label.text
        for rawValue in [0, 1, 2, 3, 4, 5, 4, 0] {
            hud.customView = customContent()
            reference.customView = customContent()
            hud.mode = try #require(TMProgressHudMode(rawValue: rawValue))
            reference.mode = try #require(MBProgressHUDMode(rawValue: rawValue))
            host.layoutIfNeeded()
            for view in [hud, reference] as [UIView] {
                view.setNeedsLayout()
                view.layoutIfNeeded()
            }
            expectFrames(hud, reference)
        }
    }

    @Test func liveTextChangesReuseConstraintsAndMatchGeometry() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud(view: host)
        let reference = MBProgressHUD(view: host)
        host.addSubview(hud)
        host.addSubview(reference)
        hud.mode = .text
        reference.mode = .text
        hud.button.addAction(UIAction { _ in }, for: .primaryActionTriggered)
        reference.button.addAction(UIAction { _ in }, for: .primaryActionTriggered)
        host.layoutIfNeeded()
        let constraintIDs = Set((hud.constraints + hud.bezelView.constraints).map(ObjectIdentifier.init))
        let scenarios: [(title: String?, details: String?, action: String?)] = [
            ("Loading", "Please wait", "Cancel"),
            ("Loading", nil, "Cancel"),
            ("Loading", nil, nil),
            (nil, "Retry", "Retry"),
            ("Done", nil, nil),
        ]
        for scenario in scenarios {
            hud.label.text = scenario.title
            reference.label.text = scenario.title
            hud.detailsLabel.text = scenario.details
            reference.detailsLabel.text = scenario.details
            hud.button.setTitle(scenario.action, for: .normal)
            reference.button.setTitle(scenario.action, for: .normal)
            host.layoutIfNeeded()
            for view in [hud, reference] as [UIView] {
                view.setNeedsLayout()
                view.layoutIfNeeded()
            }
            expectFrames(hud, reference)
            #expect(Set((hud.constraints + hud.bezelView.constraints).map(ObjectIdentifier.init)) == constraintIDs)
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

    private func customContent() -> UIView {
        let label = UILabel()
        label.text = "Custom"
        return label
    }

    private func expectFrames(_ hud: TMProgressHud, _ reference: MBProgressHUD) {
        let pairs = [
            (hud.bezelView.frame, reference.bezelView.frame),
            (hud.label.frame, reference.label.frame),
            (hud.detailsLabel.frame, reference.detailsLabel.frame),
            (hud.button.frame, reference.button.frame),
        ]
        let tolerance: CGFloat = 0.5
        for (actual, expected) in pairs {
            #expect(abs(actual.minX - expected.minX) <= tolerance)
            #expect(abs(actual.minY - expected.minY) <= tolerance)
            #expect(abs(actual.width - expected.width) <= tolerance)
            #expect(abs(actual.height - expected.height) <= tolerance)
        }
    }
}
