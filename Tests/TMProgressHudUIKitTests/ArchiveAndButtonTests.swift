import Foundation
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
        let hud = try archiveRoundTrip(TMProgressHud(frame: frame))
        #expect(hud.frame == frame)
        #expect(hud.mode == .indeterminate)
        #expect(hud.indicator is UIActivityIndicatorView)
        hud.show(animated: false)
        hud.hide(animated: false)
        let round = try archiveRoundTrip(TMRoundProgressView(frame: frame))
        #expect(round.frame == frame)
        #expect(round.progressTintColor == .white)
        let bar = try archiveRoundTrip(TMBarProgressView(frame: frame))
        #expect(bar.frame == frame)
        #expect(bar.progressColor == .white)
        let background = try archiveRoundTrip(TMBackgroundView(frame: frame))
        #expect(background.frame == frame)
        #expect(background.style == .blur)
        let button = try archiveRoundTrip(HUDRoundedButtonView(frame: frame))
        #expect(button.layer.borderWidth == 1)
    }

    @Test func decodingHUDRebuildsOneOwnedHierarchy() throws {
        var hud = TMProgressHud(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let client = UIView()
        let clientTag = 41
        client.tag = clientTag
        hud.addSubview(client)
        hud.mode = .determinate
        hud.progress = 0.75
        hud.label.text = "Loading"
        for _ in 0..<2 {
            hud = try archiveRoundTrip(hud)
            #expect(hud.subviews.filter { $0 is TMBackgroundView }.count == 2)
            #expect(hud.viewWithTag(clientTag) != nil)
            #expect(hud.mode == .indeterminate)
            #expect(hud.progress == 0)
            #expect(hud.label.text == nil)
            hud.show(animated: false)
            hud.hide(animated: false)
        }
    }

    @Test(arguments: [TMProgressHudBackgroundStyle.blur, .solidColor])
    func decodingBackgroundKeepsOneEffectView(style: TMProgressHudBackgroundStyle) throws {
        let initial = TMBackgroundView(frame: CGRect(x: 0, y: 0, width: 100, height: 80))
        initial.blurPolicy = .configured
        initial.style = style
        initial.blurEffectStyle = .dark
        initial.color = .red
        let client = UIView()
        let clientTag = 42
        client.tag = clientTag
        initial.addSubview(client)
        let decoded = try archiveRoundTrip(initial)
        #expect(decoded.blurPolicy == .system)
        decoded.blurPolicy = .configured
        #expect(decoded.subviews.compactMap { $0 as? UIVisualEffectView }.count == 1)
        #expect(decoded.viewWithTag(clientTag) != nil)
        #expect(decoded.frame == initial.frame)
        #expect(decoded.style == .blur)
        #expect(decoded.blurEffectStyle == TMBackgroundView().blurEffectStyle)
        #expect(decoded.color == nil)
    }

    @Test func unmarkedViewArchivesUseDefaultsAndAllowConfiguredBlur() throws {
        let hud = try decodeUnmarkedView(as: TMProgressHud.self)
        #expect(hud.mode == .indeterminate)
        #expect(hud.subviews.filter { $0 is TMBackgroundView }.count == 2)
        let background = try decodeUnmarkedView(as: TMBackgroundView.self)
        #expect(background.blurPolicy == .system)
        background.blurPolicy = .configured
        #expect(background.style == .blur)
        #expect(background.subviews.compactMap { $0 as? UIVisualEffectView }.count == 1)
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
        #expect(button.backgroundColor == UIColor.red.withAlphaComponent(0.1))
        button.isHighlighted = false
        #expect(button.backgroundColor == .clear)
        button.setTitleColor(nil, for: .normal)
        #expect(button.layer.borderColor == UIColor.white.cgColor)
    }

    @Test(arguments: [CGFloat(17), 31])
    func actionButtonRespectsDirectFontAndTitleChanges(fontSize: CGFloat) {
        let button = HUDRoundedButtonView(type: .custom)
        let baseline = UIButton(type: .custom)
        let receiver = ActionReceiver()
        button.addTarget(receiver, action: #selector(ActionReceiver.press), for: .primaryActionTriggered)
        for title in ["Cancel", "Cancel this download"] {
            let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
            button.titleLabel?.font = font
            baseline.titleLabel?.font = font
            button.setTitle(title, for: .normal)
            baseline.setTitle(title, for: .normal)
            let horizontalPadding: CGFloat = 20
            #expect(button.intrinsicContentSize.width == baseline.intrinsicContentSize.width + horizontalPadding)
            #expect(button.intrinsicContentSize.height == baseline.intrinsicContentSize.height)
            #expect(button.titleLabel?.font == font)
            #expect(button.configuration == nil)
        }
    }

    @Test func actionButtonSupportsSwiftActionsAndStateTitles() {
        let button = HUDRoundedButtonView(type: .custom)
        let normalTitle = "Cancel"
        let selectedTitle = "Retry"
        button.setTitle(normalTitle, for: .normal)
        button.setTitle(selectedTitle, for: .selected)
        #expect(button.intrinsicContentSize == .zero)
        var count = 0
        let action = UIAction { _ in count += 1 }
        button.addAction(action, for: .primaryActionTriggered)
        #expect(button.intrinsicContentSize.width > 0)
        button.sendActions(for: .primaryActionTriggered)
        #expect(count == 1)
        button.isSelected = true
        #expect(button.currentTitle == selectedTitle)
        button.isSelected = false
        #expect(button.currentTitle == normalTitle)
        button.removeAction(action, for: .primaryActionTriggered)
        #expect(button.intrinsicContentSize == .zero)
        button.sendActions(for: .primaryActionTriggered)
        #expect(count == 1)
    }

    @Test func inactiveStateColorsDoNotReplaceTheActiveBorder() {
        let button = HUDRoundedButtonView(type: .custom)
        button.setTitleColor(.red, for: .normal)
        button.setTitleColor(.gray, for: .disabled)
        button.setTitleColor(.green, for: .selected)
        button.setTitleColor(.blue, for: .highlighted)
        #expect(button.currentTitleColor == .red)
        #expect(button.layer.borderColor == UIColor.red.cgColor)
        button.isSelected = true
        #expect(button.layer.borderColor == UIColor.green.cgColor)
        button.isSelected = false
        button.isHighlighted = true
        #expect(button.layer.borderColor == UIColor.blue.cgColor)
        #expect(button.backgroundColor == UIColor.blue.withAlphaComponent(0.1))
        button.isHighlighted = false
        button.isEnabled = false
        #expect(button.layer.borderColor == UIColor.gray.cgColor)
        button.isEnabled = true
        #expect(button.layer.borderColor == UIColor.red.cgColor)
    }

    @Test func removingAStateColorUsesUIKitFallback() {
        let button = HUDRoundedButtonView(type: .custom)
        button.setTitleColor(.red, for: .normal)
        button.setTitleColor(.green, for: .selected)
        button.isSelected = true
        button.setTitleColor(nil, for: .selected)
        #expect(button.currentTitleColor == .red)
        #expect(button.layer.borderColor == UIColor.red.cgColor)
        button.isSelected = false
        button.setTitleColor(nil, for: .normal)
        #expect(button.currentTitleColor == .white)
        #expect(button.layer.borderColor == UIColor.white.cgColor)
    }

    private func decodeUnmarkedView<T: UIView>(as type: T.Type) throws -> T {
        let plainView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 80))
        let data = try NSKeyedArchiver.archivedData(withRootObject: plainView, requiringSecureCoding: false)
        let decoder = try NSKeyedUnarchiver(forReadingFrom: data)
        decoder.requiresSecureCoding = false
        decoder.setClass(type, forClassName: NSStringFromClass(UIView.self))
        defer { decoder.finishDecoding() }
        return try #require(decoder.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? T)
    }
}
