import Foundation
import Testing
import UIKit
@testable import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct HostLayoutTests {
    @Test(
        arguments: [
            TMProgressHudMode.indeterminate, .determinate, .annularDeterminate,
            .determinateHorizontalBar, .customView, .text,
        ].map(\.rawValue))
    func resizingHostUpdatesHUDAndContentWithoutNotifications(modeRawValue: Int) throws {
        let mode = try #require(TMProgressHudMode(rawValue: modeRawValue))
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        if mode == .customView {
            let custom = UILabel()
            custom.text = "Custom"
            hud.customView = custom
        }
        hud.mode = mode
        hud.label.text = "Loading"
        hud.detailsLabel.text = "Please wait"
        let sizes = [
            CGSize(width: 480, height: 320),
            CGSize(width: 250, height: 320),
            CGSize(width: 320, height: 480),
        ]
        let centeringTolerance: CGFloat = 0.5
        for size in sizes {
            host.bounds.size = size
            host.setNeedsLayout()
            host.layoutIfNeeded()
            #expect(hud.frame == host.bounds)
            #expect(hud.backgroundView.frame == hud.bounds)
            #expect(abs(hud.bezelView.center.x - hud.bounds.midX) <= centeringTolerance)
            #expect(abs(hud.bezelView.center.y - hud.bounds.midY) <= centeringTolerance)
        }
    }

    @Test func reparentingUsesOnlyTheCurrentHostDimensions() {
        let first = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let second = UIView(frame: CGRect(x: 20, y: 30, width: 600, height: 400))
        second.bounds.origin = CGPoint(x: 10, y: 12)
        let hud = TMProgressHud.showAdded(to: first, animated: false)
        defer { hud.hide(animated: false) }
        second.addSubview(hud)
        second.layoutIfNeeded()
        #expect(hud.frame == second.bounds)
        #expect(hud.backgroundView.frame == hud.bounds)

        first.bounds.size = CGSize(width: 200, height: 300)
        first.layoutIfNeeded()
        #expect(hud.frame == second.bounds)

        second.bounds.size = CGSize(width: 400, height: 600)
        second.setNeedsLayout()
        second.layoutIfNeeded()
        #expect(hud.frame == second.bounds)
        #expect(hud.backgroundView.frame == hud.bounds)
    }

    @Test func detachedHUDIgnoresFormerHostResizeAndCanBeAttachedAgain() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.removeFromSuperview()
        let detachedFrame = hud.frame
        host.bounds.size = CGSize(width: 480, height: 320)
        host.layoutIfNeeded()
        #expect(hud.frame == detachedFrame)
        #expect(hud.superview == nil)

        host.addSubview(hud)
        host.layoutIfNeeded()
        #expect(hud.frame == host.bounds)
        #expect(hud.backgroundView.frame == hud.bounds)
    }

    @Test func legacyOrientationNotificationDoesNotOverrideHUDFrame() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        let customFrame = CGRect(x: 4, y: 8, width: 200, height: 100)
        hud.frame = customFrame
        NotificationCenter.default.post(
            name: Notification.Name("UIApplicationDidChangeStatusBarOrientationNotification"), object: nil)
        #expect(hud.frame == customFrame)
        #expect(!hud.responds(to: NSSelectorFromString("orientationDidChange")))
    }
}
