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
        let modes: [TMProgressHudMode] = [
            .indeterminate, .determinate, .annularDeterminate,
            .determinateHorizontalBar, .customView, .text,
        ]
        var valid = true
        for mode in modes {
            let hud = TMProgressHud.showAdded(to: host, animated: false)
            hud.customView = UIView(frame: CGRect(x: 0, y: 0, width: 37, height: 37))
            hud.mode = mode
            hud.progress = 0.5
            hud.label.text = "Distribution verification"
            hud.button.setTitle("Continue", for: .normal)
            hud.button.addAction(UIAction { _ in callbacks += 1 }, for: .primaryActionTriggered)
            host.layoutIfNeeded()
            valid = valid && hud.superview === host && hud.mode == mode && hud.progress == 0.5
            hud.button.sendActions(for: .primaryActionTriggered)
            hud.hide(animated: false)
            valid = valid && hud.superview == nil
        }
        let receipt: [String: Any] = [
            "identifier": identifier, "result": valid && callbacks == modes.count ? "passed" : "failed",
            "modes": modes.count, "primaryActions": callbacks,
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
        let scenarios: [(String, TMProgressHudMode)] = [
            ("Activity indicator", .indeterminate), ("Pie progress", .determinate),
            ("Ring progress", .annularDeterminate), ("Horizontal progress", .determinateHorizontalBar),
            ("Custom content", .customView), ("Text only", .text),
        ]
        for (title, mode) in scenarios {
            let button = UIButton(configuration: .tinted())
            button.setTitle(title, for: .normal)
            button.addAction(UIAction { [weak self] _ in self?.show(mode: mode) }, for: .primaryActionTriggered)
            stack.addArrangedSubview(button)
        }
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Layout.margin),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Layout.margin),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }

    private func show(mode: TMProgressHudMode) {
        hud?.hide(animated: false)
        let presented = TMProgressHud.showAdded(to: view, animated: true)
        presented.mode = mode
        presented.label.text = "Loading"
        presented.detailsLabel.text = "An example of the selected HUD style."
        presented.progress = 0.5
        if mode == .customView {
            let configuration = UIImage.SymbolConfiguration(pointSize: Layout.symbolSize)
            presented.customView = UIImageView(
                image: UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration))
        }
        presented.button.setTitle("Close", for: .normal)
        presented.button.addAction(
            UIAction { [weak presented] _ in presented?.hide(animated: true) }, for: .primaryActionTriggered)
        hud = presented
        #if os(tvOS)
            setNeedsFocusUpdate()
            updateFocusIfNeeded()
        #endif
    }
}
