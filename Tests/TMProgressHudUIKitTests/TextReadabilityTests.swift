import Foundation
import Testing
import UIKit
import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct TextReadabilityTests {
    @Test(
        arguments: [CGFloat(240), 320],
        [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge])
    func localizedStatusFitsAtNormalAndAccessibilitySizes(width: CGFloat, category: UIContentSizeCategory) throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let root = try #require(window.rootViewController?.view)
        let host = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 800))
        root.addSubview(host)
        let messages = [
            ("Preparing your download", "Please wait while we fetch your files.", "Cancel download"),
            ("Download wird vorbereitet", "Bitte lassen Sie die App geöffnet.", "Download abbrechen"),
            ("Przygotowywanie pobierania", "Pobieramy Twoje pliki. Proszę czekać.", "Anuluj pobieranie"),
        ]
        for (title, details, actionTitle) in messages {
            let hud = TMProgressHud.showAdded(to: host, animated: false)
            defer { hud.hide(animated: false) }
            hud.traitOverrides.preferredContentSizeCategory = category
            hud.setContent(.ring)
            hud.setProgressSource(.manual(0.42))
            hud.label.text = title
            hud.detailsLabel.text = details
            hud.button.setTitle(actionTitle, for: .normal)
            var cancellations = 0
            hud.button.addAction(UIAction { _ in cancellations += 1 }, for: .primaryActionTriggered)
            window.layoutIfNeeded()
            for label in [hud.label, hud.detailsLabel] {
                let font: UIFont = label.font
                let measured = NSAttributedString(string: label.text ?? "", attributes: [.font: font])
                    .boundingRect(
                        with: CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                let textRoundingToleranceInPoints: CGFloat = 1
                #expect(label.bounds.height + textRoundingToleranceInPoints >= ceil(measured.height))
                #expect(hud.bezelView.bounds.contains(label.frame))
            }
            let buttonLabel = try #require(hud.button.titleLabel)
            let buttonFont: UIFont = buttonLabel.font
            #expect(hud.button.bounds.height + 1 >= buttonFont.lineHeight)
            #expect(hud.bezelView.bounds.contains(hud.button.frame))
            #expect(host.bounds.contains(hud.bezelView.frame))
            #expect(buttonLabel.lineBreakMode == .byTruncatingTail)
            #expect(hud.button.currentTitle == actionTitle)
            hud.button.sendActions(for: .primaryActionTriggered)
            #expect(cancellations == 1)
        }
    }
}
