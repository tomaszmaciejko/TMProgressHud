import Testing
import UIKit

@MainActor
func makeHostedTestWindow() throws -> UIWindow {
    let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIViewController()
    window.isHidden = false
    return window
}
