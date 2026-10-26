import Foundation
import TMProgressHudUIKit

/// Records synchronous KVO for HUD mutations performed on the main actor.
@MainActor
final class HUDChangeRecorder {
    private(set) var count = 0

    func observe<Value>(
        _ hud: TMProgressHud, _ keyPath: KeyPath<TMProgressHud, Value>,
        verify: @escaping @MainActor (TMProgressHud) -> Void
    ) -> NSKeyValueObservation {
        let verifyOnActor: @MainActor () -> Void = { [weak hud] in
            guard let hud else { return }
            verify(hud)
        }
        return hud.observe(keyPath, options: [.new]) { [weak self] _, _ in
            // KVO is delivered by these main-actor mutations. Check that contract synchronously;
            // an asynchronous hop would miss partially updated selections inside the notification.
            MainActor.assumeIsolated {
                verifyOnActor()
                self?.count += 1
            }
        }
    }
}
