import TMProgressHudUIKit
import UIKit

@main
final class DemoApp: UIResponder, UIApplicationDelegate {}

final class DemoScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UINavigationController(rootViewController: HUDDemoViewController())
        self.window = window
        window.makeKeyAndVisible()
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--tmhud-check-id"), arguments.indices.contains(index + 1) {
            verifyDistribution(in: window.rootViewController?.view ?? window, identifier: arguments[index + 1])
        }
    }

    private func verifyDistribution(in host: UIView, identifier: String) {
        var callbacks = 0
        let scenarios: [(TMProgressHudContent, TMProgressHudMode)] = [
            (.activity, .indeterminate), (.outlinedCircle, .determinate), (.ring, .annularDeterminate),
            (.bar, .determinateHorizontalBar),
            (.custom(UIView(frame: CGRect(x: 0, y: 0, width: 37, height: 37))), .customView),
            (.text, .text),
        ]
        var valid = true
        for (content, expectedMode) in scenarios {
            let hud = TMProgressHud.showAdded(to: host, animated: false)
            hud.setContent(content)
            hud.setProgressSource(.manual(0.5))
            hud.label.text = "Distribution verification"
            hud.button.setTitle("Continue", for: .normal)
            hud.button.addAction(UIAction { _ in callbacks += 1 }, for: .primaryActionTriggered)
            host.layoutIfNeeded()
            valid = valid && hud.superview === host && hud.mode == expectedMode && hud.progress == 0.5
            hud.button.sendActions(for: .primaryActionTriggered)
            hud.hide(animated: false)
            valid = valid && hud.superview == nil
        }
        let demo = (window?.rootViewController as? UINavigationController)?.topViewController as? HUDDemoViewController
        let safeAreaLayouts = demo?.verifySafeAreaLayout() ?? 0
        let expectedSafeAreaLayouts = 6
        let receipt: [String: Any] = [
            "identifier": identifier,
            "result": valid && callbacks == scenarios.count && safeAreaLayouts == expectedSafeAreaLayouts
                ? "passed" : "failed",
            "modes": scenarios.count, "primaryActions": callbacks, "safeAreaLayouts": safeAreaLayouts,
        ]
        do {
            let folder = try FileManager.default.url(
                for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let data = try JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys])
            try data.write(to: folder.appendingPathComponent("TMProgressHud-verification.json"), options: .atomic)
        } catch {
            NSLog("TMProgressHud distribution verification could not save its receipt: %@", error.localizedDescription)
        }
    }
}

final class HUDDemoViewController: UIViewController {
    private enum Layout {
        static let margin: CGFloat = 24
        static let spacing: CGFloat = 12
        static let symbolSize: CGFloat = 37
    }

    private weak var hud: TMProgressHud?

    #if os(tvOS)
        override var preferredFocusEnvironments: [any UIFocusEnvironment] {
            if let hud, hud.alpha > 0 { return [hud.button] }
            return super.preferredFocusEnvironments
        }
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "TMProgressHud · UIKit"
        #if os(tvOS)
            view.backgroundColor = .black
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        #else
            view.backgroundColor = .systemBackground
        #endif
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        let configuration = UIImage.SymbolConfiguration(pointSize: Layout.symbolSize)
        let custom = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration))
        let scenarios: [(String, TMProgressHudContent)] = [
            ("Activity indicator", .activity), ("Circular progress", .outlinedCircle),
            ("Ring progress", .ring), ("Horizontal progress", .bar),
            ("Custom content", .custom(custom)), ("Text only", .text),
        ]
        for (title, content) in scenarios {
            let button = UIButton(configuration: .tinted())
            button.setTitle(title, for: .normal)
            button.addAction(UIAction { [weak self] _ in self?.show(content: content) }, for: .primaryActionTriggered)
            stack.addArrangedSubview(button)
        }
        let bottomExample = UIButton(configuration: .tinted())
        bottomExample.setTitle("Bottom placement", for: .normal)
        bottomExample.addAction(
            UIAction { [weak self] _ in
                self?.show(content: .text, position: .init(vertical: .bottom))
            }, for: .primaryActionTriggered)
        stack.addArrangedSubview(bottomExample)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Layout.margin),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Layout.margin),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        guard let hud else { return }
        var layout = hud.layoutConfiguration
        layout.hostInsets = safeAreaHostInsets
        hud.setLayout(layout)
    }

    private var safeAreaHostInsets: UIEdgeInsets {
        let safe = view.safeAreaInsets
        let spacing = TMProgressHudLayout.defaultInsets
        return UIEdgeInsets(
            top: safe.top + spacing.top, left: safe.left + spacing.left,
            bottom: safe.bottom + spacing.bottom, right: safe.right + spacing.right)
    }

    private func show(
        content: TMProgressHudContent, position: TMProgressHudPosition = .init(), animated: Bool = true
    ) {
        hud?.hide(animated: false)
        let presented = TMProgressHud(view: view)
        presented.removeFromSuperViewOnHide = true
        presented.setLayout(.init(position: position, hostInsets: safeAreaHostInsets))
        presented.setContent(content)
        presented.label.text = "Loading"
        presented.detailsLabel.text = "An example of the selected HUD style."
        presented.setProgressSource(.manual(0.5))
        presented.button.setTitle("Close", for: .normal)
        presented.button.addAction(
            UIAction { [weak presented] _ in presented?.hide(animated: true) }, for: .primaryActionTriggered)
        view.addSubview(presented)
        hud = presented
        presented.show(animated: animated)
        #if os(tvOS)
            setNeedsFocusUpdate()
            updateFocusIfNeeded()
        #endif
    }

    // Invoked only by the distribution consumer's explicit verification mode.
    func verifySafeAreaLayout() -> Int {
        let originalInsets = additionalSafeAreaInsets
        let originalDirection = view.semanticContentAttribute
        defer {
            hud?.hide(animated: false)
            additionalSafeAreaInsets = originalInsets
            view.semanticContentAttribute = originalDirection
        }
        let extraInsets: [UIEdgeInsets] = [.zero, .init(top: 24, left: 12, bottom: 40, right: 16)]
        let alignments: [TMProgressHudPosition.Horizontal] = [.left, .center, .right]
        // Centering an odd pixel width can shift the rounded frame by half a physical pixel.
        let pixelRoundingInPoints = 0.5 / view.traitCollection.displayScale
        let floatingPointToleranceInPoints: CGFloat = 0.001
        let precisionInPoints = pixelRoundingInPoints + floatingPointToleranceInPoints
        var checked = 0
        for horizontal in alignments {
            show(content: .text, position: .init(horizontal: horizontal, vertical: .bottom), animated: false)
            for insets in extraInsets {
                additionalSafeAreaInsets = insets
                view.semanticContentAttribute = insets == .zero ? .forceLeftToRight : .forceRightToLeft
                view.window?.layoutIfNeeded()
                guard let hud else { return checked }
                let frame = hud.bezelView.frame
                let safe = view.safeAreaInsets
                let spacing = TMProgressHudLayout.defaultInsets
                let expectedBottom = view.bounds.maxY - safe.bottom - spacing.bottom
                guard abs(frame.maxY - expectedBottom) <= precisionInPoints else {
                    NSLog(
                        "Safe area bottom mismatch at \(checked): frame=\(frame), expected=\(expectedBottom), safe=\(safe)"
                    )
                    return checked
                }
                let horizontalDifference: CGFloat
                switch horizontal {
                case .left: horizontalDifference = frame.minX - view.bounds.minX - safe.left - spacing.left
                case .center: horizontalDifference = frame.midX - view.bounds.midX
                case .right: horizontalDifference = frame.maxX - view.bounds.maxX + safe.right + spacing.right
                }
                guard abs(horizontalDifference) <= precisionInPoints else {
                    NSLog(
                        "Safe area horizontal mismatch at \(checked): frame=\(frame), delta=\(horizontalDifference), bounds=\(view.bounds)"
                    )
                    return checked
                }
                checked += 1
            }
        }
        return checked
    }

}
