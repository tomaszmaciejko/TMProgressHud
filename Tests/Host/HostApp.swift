import UIKit

@main
final class HostApp: UIResponder, UIApplicationDelegate {}

final class HostScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        #if os(tvOS)
            controller.view.backgroundColor = .black
        #else
            controller.view.backgroundColor = .systemBackground
        #endif
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()
    }
}
