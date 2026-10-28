import Testing
import UIKit
import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct VisibilityLayoutTests {
    enum Content: CaseIterable, Sendable { case title, details, action, custom }

    @Test(arguments: Content.allCases)
    func hiddenContentCollapsesAndRestoresWithoutRemovingClientConstraints(content: Content) throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.setContent(.text)
        hud.label.text = "Loading"
        let hiddenView: UIView
        var clientConstraints: [NSLayoutConstraint] = []
        switch content {
        case .title:
            hud.detailsLabel.text = "Keep the description"
            hiddenView = hud.label
        case .details:
            hud.detailsLabel.text = "Hide the description"
            hiddenView = hud.detailsLabel
        case .action:
            hud.button.setTitle("Cancel", for: .normal)
            hud.button.addAction(UIAction { _ in }, for: .primaryActionTriggered)
            hiddenView = hud.button
        case .custom:
            let custom = UIView()
            clientConstraints = [
                custom.widthAnchor.constraint(equalToConstant: 100),
                custom.heightAnchor.constraint(equalToConstant: 30),
            ]
            NSLayoutConstraint.activate(clientConstraints)
            hud.setContent(.custom(custom))
            hiddenView = custom
        }
        window.layoutIfNeeded()
        let expandedHeight = hud.bezelView.bounds.height
        let contentHeight = hiddenView.bounds.height
        #expect(contentHeight > 0)
        let expectedCollapsedHeight = expandedHeight - contentHeight - 4
        let precisionInPoints: CGFloat = 0.001
        for _ in 0..<3 {
            hiddenView.isHidden = true
            window.layoutIfNeeded()
            #expect(abs(hud.bezelView.bounds.height - expectedCollapsedHeight) <= precisionInPoints)
            #expect(clientConstraints.allSatisfy { $0.isActive })
            hiddenView.isHidden = false
            window.layoutIfNeeded()
            #expect(abs(hud.bezelView.bounds.height - expandedHeight) <= precisionInPoints)
            #expect(clientConstraints.allSatisfy { $0.isActive })
        }
    }

    @Test func hidingAllContentLeavesOnlyTheConfiguredInsets() throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.setContent(.text)
        hud.label.text = "Loading"
        hud.detailsLabel.text = "Details"
        window.layoutIfNeeded()
        hud.label.isHidden = true
        hud.detailsLabel.isHidden = true
        window.layoutIfNeeded()
        #expect(hud.bezelView.bounds.height == 40)
        hud.label.isHidden = false
        window.layoutIfNeeded()
        #expect(hud.bezelView.bounds.height > 40)
    }
    @Test func contentChangesKeepBezelPlacementAndSizingConstraints() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.label.text = "Loading"
        hud.detailsLabel.text = "Please wait"
        hud.minSize = CGSize(width: 120, height: 100)
        hud.isSquare = true
        host.layoutIfNeeded()
        let placement = Set(hud.constraints.map(ObjectIdentifier.init))
        let sizing = hud.bezelView.constraints.filter { constraint in
            constraint.firstItem === hud.bezelView
                && (constraint.secondItem == nil || constraint.secondItem === hud.bezelView)
        }
        #expect(!placement.isEmpty)
        #expect(!sizing.isEmpty)
        // UIKit rounds view frames to pixels; the detached tvOS fixture has a one-point pixel.
        let pixelRoundingTolerance: CGFloat = 0.5
        for content in [TMProgressHudContent.text, .ring, .bar, .activity] {
            hud.setContent(content)
            hud.detailsLabel.isHidden = true
            host.layoutIfNeeded()
            #expect(Set(hud.constraints.map(ObjectIdentifier.init)) == placement)
            #expect(sizing.allSatisfy { $0.isActive })
            hud.detailsLabel.isHidden = false
            host.layoutIfNeeded()
            #expect(Set(hud.constraints.map(ObjectIdentifier.init)) == placement)
            #expect(sizing.allSatisfy { $0.isActive })
            #expect(abs(hud.bezelView.frame.midX - host.bounds.midX) <= pixelRoundingTolerance)
            #expect(abs(hud.bezelView.frame.midY - host.bounds.midY) <= pixelRoundingTolerance)
            #expect(hud.bezelView.bounds.width == hud.bezelView.bounds.height)
        }
    }

}
