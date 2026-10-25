import Foundation
import MBProgressHUDReference
import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class ActionReceiver: NSObject {
    var count = 0
    @objc func press() { count += 1 }
}

@Suite(.serialized)
@MainActor
struct ArchiveAndButtonTests {
    @Test func supportedCoderInitializersRestoreUsableViews() throws {
        let frame = CGRect(x: 10, y: 20, width: 120, height: 80)
        let hud = try roundTrip(TMProgressHud(frame: frame))
        #expect(hud.frame == frame)
        #expect(hud.mode == .indeterminate)
        #expect(hud.indicator is UIActivityIndicatorView)
        hud.show(animated: false)
        hud.hide(animated: false)
        let round = try roundTrip(TMRoundProgressView(frame: frame))
        #expect(round.frame == frame)
        #expect(round.progressTintColor == .white)
        let bar = try roundTrip(TMBarProgressView(frame: frame))
        #expect(bar.frame == frame)
        #expect(bar.progressColor == .white)
        let background = try roundTrip(TMBackgroundView(frame: frame))
        #expect(background.frame == frame)
        #expect(background.style == .blur)
        let button = try roundTrip(HUDRoundedButtonView(frame: frame))
        #expect(button.layer.borderWidth == 1)
    }

    @Test(arguments: [UIControl.Event.touchUpInside, .primaryActionTriggered])
    func actionButtonVisibilityShapeAndColors(event: UIControl.Event) {
        let button = HUDRoundedButtonView(frame: CGRect(x: 0, y: 0, width: 120, height: 31))
        #expect(button.intrinsicContentSize == .zero)
        let receiver = ActionReceiver()
        button.addTarget(receiver, action: #selector(ActionReceiver.press), for: event)
        #expect(button.intrinsicContentSize == .zero)
        button.setTitle("Cancel", for: .normal)
        #expect(button.intrinsicContentSize.width > 20)
        button.sendActions(for: event)
        #expect(receiver.count == 1)
        button.layoutSubviews()
        #expect(button.layer.cornerRadius == 16)
        button.setTitleColor(.red, for: .normal)
        button.setTitleColor(.green, for: .selected)
        button.isHighlighted = true
        let reference = MBProgressHUD(view: UIView()).button
        reference.setTitleColor(.green, for: .selected)
        reference.isHighlighted = true
        #expect(button.backgroundColor == reference.backgroundColor)
        button.isHighlighted = false
        #expect(button.backgroundColor == .clear)
        button.setTitleColor(nil, for: .normal)
        #expect(button.layer.borderColor == nil)
    }

    private func roundTrip<T: UIView>(_ view: T) throws -> T {
        let data = try NSKeyedArchiver.archivedData(withRootObject: view, requiringSecureCoding: false)
        let decoder = try NSKeyedUnarchiver(forReadingFrom: data)
        decoder.requiresSecureCoding = false
        defer { decoder.finishDecoding() }
        return try #require(decoder.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? T)
    }
}
