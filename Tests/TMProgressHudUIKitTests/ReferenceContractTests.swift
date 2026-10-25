import MBProgressHUDReference
import Testing
import UIKit
@testable import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct ReferenceContractTests {
    @Test func platformDefaultsAndOrientationObservationMatchOriginal() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let reference = MBProgressHUD(view: host)
        let port = TMProgressHud(view: host)
        #expect(port.bezelView.blurEffectStyle == reference.bezelView.blurEffectStyle)
        host.addSubview(reference)
        host.addSubview(port)
        let detachedFrame = CGRect(x: 4, y: 8, width: 200, height: 100)
        reference.frame = detachedFrame
        port.frame = detachedFrame
        NotificationCenter.default.post(
            name: Notification.Name("UIApplicationDidChangeStatusBarOrientationNotification"), object: nil)
        #expect(port.frame == reference.frame)
        #if os(tvOS)
            #expect(port.frame == detachedFrame)
            #expect(!port.responds(to: NSSelectorFromString("orientationDidChange")))
        #else
            #expect(port.frame == host.bounds)
        #endif
    }

    @Test func completedHUDsDoNotRetainThemselves() {
        weak var portReference: TMProgressHud?
        weak var originalReference: MBProgressHUD?
        autoreleasepool {
            let port = TMProgressHud(frame: .zero)
            let original = MBProgressHUD(frame: .zero)
            portReference = port
            originalReference = original
            port.show(animated: false)
            original.show(animated: false)
            port.hide(animated: false)
            original.hide(animated: false)
        }
        #expect(portReference == nil)
        #expect(originalReference == nil)
    }

    @Test func originalDefaultsAndHostLookup() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = MBProgressHUD(view: host)
        #expect(hud.frame == host.bounds)
        #expect(hud.superview == nil)
        #expect(hud.mode == .indeterminate)
        #expect(hud.margin == 20)
        #expect(hud.graceTime == 0)
        #expect(hud.minShowTime == 0)
        #expect(hud.progress == 0)
        #expect(!hud.removeFromSuperViewOnHide)
        #if os(tvOS)
            #expect(hud.bezelView.blurEffectStyle == .regular)
        #else
            #expect(hud.bezelView.blurEffectStyle == .systemThickMaterial)
        #endif
        host.addSubview(hud)
        #expect(MBProgressHUD.forView(host) === hud)
        hud.hide(animated: false)
        #expect(MBProgressHUD.forView(host) == nil)
    }
}
