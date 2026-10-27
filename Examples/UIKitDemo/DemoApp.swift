import Accessibility
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
            let identifier = arguments[index + 1]
            Task { [weak self] in
                await self?.verifyDistribution(in: window.rootViewController?.view ?? window, identifier: identifier)
            }
        }
    }

    private func verifyDistribution(in host: UIView, identifier: String) async {
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
        let operationPaths = await demo?.verifyOperationPaths() ?? 0
        let expectedOperationPaths = 3
        let receipt: [String: Any] = [
            "identifier": identifier,
            "result": valid && callbacks == scenarios.count && safeAreaLayouts == expectedSafeAreaLayouts
                && operationPaths == expectedOperationPaths
                ? "passed" : "failed",
            "modes": scenarios.count, "primaryActions": callbacks,
            "safeAreaLayouts": safeAreaLayouts, "operationPaths": operationPaths,
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

    private enum ExampleOperation {
        static let totalSteps = 10
        static let stepDelay: Duration = .milliseconds(200)
        enum Failure: Error { case requested }
    }

    private weak var hud: TMProgressHud?
    private var operationTask: Task<Void, Never>?
    private let operationResultLabel = UILabel()

    deinit { operationTask?.cancel() }

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
        addModeButtons(to: stack)
        addOperationButtons(to: stack)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Layout.margin),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Layout.margin),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }

    private func addModeButtons(to stack: UIStackView) {
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
            button.addAction(
                UIAction { [weak self, weak button] _ in
                    self?.show(content: content, returnFocusTo: button)
                }, for: .primaryActionTriggered)
            stack.addArrangedSubview(button)
        }
        let bottom = UIButton(configuration: .tinted())
        bottom.setTitle("Bottom placement", for: .normal)
        bottom.addAction(
            UIAction { [weak self, weak bottom] _ in
                self?.show(content: .text, position: .init(vertical: .bottom), returnFocusTo: bottom)
            }, for: .primaryActionTriggered)
        stack.addArrangedSubview(bottom)
    }

    private func addOperationButtons(to stack: UIStackView) {
        for (title, failure) in [("Operation: success", false), ("Operation: failure", true)] {
            let button = UIButton(configuration: .tinted())
            button.setTitle(title, for: .normal)
            button.addAction(
                UIAction { [weak self, weak button] _ in
                    self?.startOperation(shouldFail: failure, source: button)
                }, for: .primaryActionTriggered)
            stack.addArrangedSubview(button)
        }
        operationResultLabel.textAlignment = .center
        operationResultLabel.numberOfLines = 0
        operationResultLabel.font = .preferredFont(forTextStyle: .footnote)
        operationResultLabel.adjustsFontForContentSizeCategory = true
        stack.addArrangedSubview(operationResultLabel)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        operationTask?.cancel()
        hud?.hide(animated: false)
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

    private func makeHUD(content: TMProgressHudContent, position: TMProgressHudPosition = .init()) -> TMProgressHud {
        operationTask?.cancel()
        hud?.hide(animated: false)
        let presented = TMProgressHud(view: view)
        presented.removeFromSuperViewOnHide = true
        presented.accessibilityViewIsModal = true
        presented.setLayout(.init(position: position, hostInsets: safeAreaHostInsets))
        presented.setContent(content)
        presented.label.text = "Loading"
        presented.detailsLabel.text = "An example of the selected HUD style."
        presented.setProgressSource(.manual(0.5))
        return presented
    }

    private func presentHUD(_ presented: TMProgressHud, animated: Bool) {
        view.addSubview(presented)
        hud = presented
        let voiceOver = UIAccessibility.isVoiceOverRunning
        presented.show(animated: animated && !voiceOver)
        if voiceOver { AccessibilityNotification.ScreenChanged(presented.button).post() }
        #if os(tvOS)
            setNeedsFocusUpdate()
            updateFocusIfNeeded()
        #endif
    }

    private func show(
        content: TMProgressHudContent, position: TMProgressHudPosition = .init(), animated: Bool = true,
        returnFocusTo source: UIView? = nil
    ) {
        let presented = makeHUD(content: content, position: position)
        presented.button.setTitle("Close", for: .normal)
        presented.button.addAction(
            UIAction { [weak self, weak presented, weak source] _ in
                guard let presented else { return }
                self?.dismiss(presented, returningFocusTo: source)
            }, for: .primaryActionTriggered)
        presentHUD(presented, animated: animated)
    }

    private func dismiss(
        _ presented: TMProgressHud, returningFocusTo source: UIView?, result: String? = nil, animated: Bool = true
    ) {
        presented.hide(animated: animated) { [weak self, weak presented, weak source] _ in
            // An older request must not replace a newer result or move its accessibility focus.
            guard let self, self.hud === presented else { return }
            self.hud = nil
            if let result { self.operationResultLabel.text = result }
            guard self.viewIfLoaded?.window != nil else { return }
            if UIAccessibility.isVoiceOverRunning {
                AccessibilityNotification.ScreenChanged(result == nil ? source : self.operationResultLabel).post()
            }
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
        }
    }

    @discardableResult
    private func startOperation(
        shouldFail: Bool, source: UIView? = nil, animated: Bool = true,
        stepDelay: Duration = ExampleOperation.stepDelay
    ) -> Task<Void, Never> {
        let presented = makeHUD(content: .ring)
        presented.label.text = "Example operation"
        presented.detailsLabel.text = "The application owns this task and its cancellation."
        presented.setProgressSource(.manual(0))
        presented.button.setTitle("Cancel", for: .normal)
        presented.button.addAction(
            UIAction { [weak self] _ in self?.operationTask?.cancel() }, for: .primaryActionTriggered)
        presentHUD(presented, animated: animated)
        let task = Task { [weak self, weak source] in
            var result = "Operation cancelled"
            defer {
                if let self {
                    self.dismiss(presented, returningFocusTo: source, result: result, animated: animated)
                } else {
                    presented.hide(animated: false)
                }
            }
            do {
                for step in 1...ExampleOperation.totalSteps {
                    try await Task.sleep(for: stepDelay)
                    presented.setProgressSource(.manual(Float(step) / Float(ExampleOperation.totalSteps)))
                }
                if shouldFail { throw ExampleOperation.Failure.requested }
                result = "Operation finished"
            } catch is CancellationError {
                result = "Operation cancelled"
            } catch {
                result = "Example operation failed"
            }
        }
        operationTask = task
        return task
    }

    func verifyOperationPaths() async -> Int {
        let cases = [
            (false, false, "Operation finished"), (true, false, "Example operation failed"),
            (false, true, "Operation cancelled"),
        ]
        var checked = 0
        for (failure, cancel, expected) in cases {
            let task = startOperation(shouldFail: failure, animated: false, stepDelay: .zero)
            if cancel { hud?.button.sendActions(for: .primaryActionTriggered) }
            await task.value
            guard operationResultLabel.text == expected, hud == nil,
                !view.subviews.contains(where: { $0 is TMProgressHud })
            else { return checked }
            checked += 1
        }
        return checked
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
