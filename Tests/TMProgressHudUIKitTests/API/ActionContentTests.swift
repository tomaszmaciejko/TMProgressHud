import Foundation
import Testing
import UIKit
import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct ActionContentTests {
    enum Content: CaseIterable, Sendable {
        case plain, attributed, image, configuredTitle, configuredSubtitle, configuredImage, configuredActivity

        var usesConfiguration: Bool {
            switch self {
            case .plain, .attributed, .image: false
            default: true
            }
        }
    }

    @Test(arguments: Content.allCases)
    func supportedContentUsesNativeSizeAndKeepsTheAction(content: Content) {
        let hud = TMProgressHud(frame: .zero)
        let button = hud.button
        let native = UIButton(type: .custom)
        if !content.usesConfiguration { native.titleLabel?.font = button.titleLabel?.font }
        configure(button, content: content)
        configure(native, content: content)
        #expect(button.intrinsicContentSize == .zero)
        var calls = 0
        let action = UIAction { _ in calls += 1 }
        button.addAction(action, for: .primaryActionTriggered)
        let padding: CGFloat = content.usesConfiguration ? 0 : 20
        #expect(button.intrinsicContentSize.width == native.intrinsicContentSize.width + padding)
        #expect(button.intrinsicContentSize.height == native.intrinsicContentSize.height)
        #expect(button.intrinsicContentSize.width > 0)
        #expect(button.intrinsicContentSize.height > 0)
        button.sendActions(for: .primaryActionTriggered)
        #expect(calls == 1)
        button.removeAction(action, for: .primaryActionTriggered)
        #expect(button.intrinsicContentSize == .zero)
    }

    @Test(arguments: Content.allCases)
    func replacingContentAfterLayoutUpdatesSize(content: Content) throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.setContent(.text)
        hud.label.text = "Loading"
        hud.button.addAction(UIAction { _ in }, for: .primaryActionTriggered)
        window.layoutIfNeeded()
        #expect(hud.button.bounds.size == .zero)
        configure(hud.button, content: content)
        window.layoutIfNeeded()
        #expect(hud.button.bounds.width > 0)
        #expect(hud.button.bounds.height > 0)
        hud.button.configuration = nil
        hud.button.setTitle(nil, for: .normal)
        hud.button.setAttributedTitle(nil, for: .normal)
        hud.button.setImage(nil, for: .normal)
        #expect(hud.button.intrinsicContentSize == .zero)
        window.layoutIfNeeded()
        #expect(hud.button.bounds.size == .zero)
    }

    @Test func stateSpecificContentAppearsAndCollapsesWithTheState() throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.setContent(.text)
        hud.label.text = "Loading"
        hud.button.setTitle("Retry", for: .selected)
        hud.button.addAction(UIAction { _ in }, for: .primaryActionTriggered)
        window.layoutIfNeeded()
        #expect(hud.button.bounds.size == .zero)
        hud.button.isSelected = true
        window.layoutIfNeeded()
        #expect(hud.button.bounds.width > 0)
        #expect(hud.button.bounds.height > 0)
        hud.button.isSelected = false
        window.layoutIfNeeded()
        #expect(hud.button.bounds.size == .zero)
    }

    @Test func configurationOwnsItsAppearanceAndRemovingItRestoresTheDefaultBorder() {
        let hud = TMProgressHud(frame: .zero)
        let button = hud.button
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Cancel"
        configuration.background.strokeColor = .blue
        configuration.background.strokeWidth = 3
        button.configuration = configuration
        button.layoutIfNeeded()
        #expect(button.layer.borderWidth == 0)
        #expect(button.layer.cornerRadius == 0)
        button.isHighlighted = true
        #expect(button.configuration?.background.strokeColor == .blue)
        #expect(button.configuration?.background.strokeWidth == 3)
        #expect(button.backgroundColor == .clear)
        button.configuration = nil
        button.isHighlighted = false
        button.setTitleColor(.red, for: .normal)
        button.layoutIfNeeded()
        #expect(button.layer.borderWidth == 1)
        #expect(button.layer.borderColor == UIColor.red.cgColor)
    }

    private func configure(_ button: UIButton, content: Content) {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        switch content {
        case .plain: button.setTitle("Cancel", for: .normal)
        case .attributed:
            button.setAttributedTitle(NSAttributedString(string: "Cancel"), for: .normal)
        case .image:
            button.setImage(image, for: .normal)
        case .configuredTitle, .configuredSubtitle, .configuredImage, .configuredActivity:
            var configuration = UIButton.Configuration.filled()
            switch content {
            case .configuredTitle: configuration.attributedTitle = AttributedString("Cancel")
            case .configuredSubtitle: configuration.subtitle = "Cancel"
            case .configuredImage: configuration.image = image
            default: configuration.showsActivityIndicator = true
            }
            configuration.contentInsets = .init(top: 7, leading: 11, bottom: 7, trailing: 11)
            button.configuration = configuration
        }
    }
}
