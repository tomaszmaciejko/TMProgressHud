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
}
