import Foundation
import Testing
import UIKit
import TMProgressHudUIKit

@MainActor
private final class LateActionTarget: NSObject {
    var calls = 0
    @objc func invoke() { calls += 1 }
}

@Suite(.serialized)
@MainActor
struct LateActionLayoutTests {
    enum Registration: Sendable { case targetAction, swiftAction }

    @Test(arguments: [Registration.targetAction, .swiftAction])
    func registeringAndRemovingActionsUpdatesAnAlreadyLaidOutButton(registration: Registration) throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.setContent(.text)
        hud.label.text = "Loading"
        hud.button.setTitle("Cancel", for: .normal)
        window.layoutIfNeeded()
        #expect(hud.button.bounds.size == .zero)
        let initialHeight = hud.bezelView.bounds.height
        let target = LateActionTarget()
        let action = UIAction(identifier: .init("late-action")) { _ in target.invoke() }
        switch registration {
        case .targetAction:
            hud.button.addTarget(target, action: #selector(LateActionTarget.invoke), for: .primaryActionTriggered)
        case .swiftAction:
            hud.button.addAction(action, for: .primaryActionTriggered)
        }
        window.layoutIfNeeded()
        #expect(hud.button.bounds.width > 0)
        #expect(hud.button.bounds.height > 0)
        #expect(hud.button.intrinsicContentSize.width > 0)
        let layoutPrecisionInPoints: CGFloat = 0.001
        #expect(abs(hud.button.frame.minY - hud.label.frame.maxY - 4) <= layoutPrecisionInPoints)
        hud.button.sendActions(for: .primaryActionTriggered)
        #expect(target.calls == 1)
        switch registration {
        case .targetAction:
            hud.button.removeTarget(target, action: #selector(LateActionTarget.invoke), for: .primaryActionTriggered)
        case .swiftAction:
            hud.button.removeAction(identifiedBy: action.identifier, for: .primaryActionTriggered)
        }
        window.layoutIfNeeded()
        #expect(hud.button.bounds.size == .zero)
        #expect(abs(hud.bezelView.bounds.height - initialHeight) <= layoutPrecisionInPoints)
        hud.button.sendActions(for: .primaryActionTriggered)
        #expect(target.calls == 1)
    }
}
