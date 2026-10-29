import Foundation
import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class MotionPreferenceStub {
    var enabled = false
}

private final class NotificationCapture: Sendable {}

@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct MotionPolicyTests {
    @Test(arguments: [false, true])
    func policiesResolveTheSystemSetting(systemValue: Bool) {
        #expect(TMProgressHudMotionPolicy.system.reducesMotion(systemValue: systemValue) == systemValue)
        #expect(TMProgressHudMotionPolicy.reduced.reducesMotion(systemValue: systemValue))
        #expect(!TMProgressHudMotionPolicy.full.reducesMotion(systemValue: systemValue))
    }

    @Test func policyChangesPreserveTheRequestedFlagAndClientEffects() {
        let hud = TMProgressHud(frame: .zero)
        #expect(hud.motionPolicy == .system)
        hud.motionPolicy = .full
        let client = UIInterpolatingMotionEffect(keyPath: "alpha", type: .tiltAlongHorizontalAxis)
        hud.bezelView.addMotionEffect(client)
        hud.areDefaultMotionEffectsEnabled = true
        #expect(hud.bezelView.motionEffects.count == 2)
        hud.motionPolicy = .reduced
        #expect(hud.areDefaultMotionEffectsEnabled)
        #expect(hud.bezelView.motionEffects.count == 1)
        #expect(hud.bezelView.motionEffects.first === client)
        hud.motionPolicy = .reduced
        hud.motionPolicy = .full
        #expect(hud.bezelView.motionEffects.count == 2)
    }

    @Test func reducedZoomUsesFadeAndFinishesNormally() async throws {
        let hud = TMProgressHud(frame: .zero)
        hud.motionPolicy = .reduced
        hud.animationType = .zoomIn
        hud.show(animated: false)
        let finished = CallbackExpectation()
        hud.hide(animated: true) { _ in finished.signal() }
        #expect(hud.bezelView.transform == .identity)
        try await finished.wait()
        #expect(hud.alpha == 0)
    }

    @Test func settingNotificationsArriveOnTheMainActor() async throws {
        let center = NotificationCenter()
        let preference = MotionPreferenceStub()
        let changed = CallbackExpectation()
        let settings = HUDMotionSettings(center: center, systemValue: { preference.enabled }) {
            #expect(Thread.isMainThread)
            changed.signal()
        }
        #expect(!settings.shouldReduceMotion)
        preference.enabled = true
        await Task.detached {
            center.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        }.value
        try await changed.wait()
        #expect(settings.shouldReduceMotion)
    }

    @Test func aSystemChangeUpdatesExistingHUDEffects() async throws {
        let hud = TMProgressHud(frame: .zero)
        let center = NotificationCenter()
        let preference = MotionPreferenceStub()
        let updated = CallbackExpectation()
        hud.motionSettings = HUDMotionSettings(center: center, systemValue: { preference.enabled }) { [weak hud] in
            hud?.updateBezelMotionEffects()
            updated.signal()
        }
        hud.areDefaultMotionEffectsEnabled = true
        #expect(hud.bezelView.motionEffects.count == 1)
        preference.enabled = true
        center.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        try await updated.wait()
        #expect(hud.bezelView.motionEffects.isEmpty)
        #expect(hud.areDefaultMotionEffectsEnabled)
    }

    @Test func releasingATokenRemovesOnlyItsOwnRegistration() async throws {
        let center = NotificationCenter()
        let name = UIAccessibility.reduceMotionStatusDidChangeNotification
        let unrelatedDelivery = CallbackExpectation()
        let unrelatedToken = center.addObserver(forName: name, object: nil, queue: nil) { _ in
            unrelatedDelivery.signal()
        }
        defer { center.removeObserver(unrelatedToken) }

        weak var retainedByRegistration: NotificationCapture?
        autoreleasepool {
            let capture = NotificationCapture()
            retainedByRegistration = capture
            let token = center.addObserver(forName: name, object: nil, queue: nil) { [capture] _ in
                withExtendedLifetime(capture) {}
            }
            let registration = HUDNotificationToken(center: center, token: token)
            withExtendedLifetime(registration) {
                #expect(retainedByRegistration != nil)
            }
        }
        #expect(retainedByRegistration == nil)
        center.post(name: name, object: nil)
        try await unrelatedDelivery.wait()
    }

    @Test func observationDoesNotRetainItsOwners() {
        weak var hudReference: TMProgressHud?
        weak var settingsReference: HUDMotionSettings?
        autoreleasepool {
            let hud = TMProgressHud(frame: .zero)
            hud.motionPolicy = .full
            hudReference = hud
            settingsReference = hud.motionSettings
        }
        #expect(hudReference == nil)
        #expect(settingsReference == nil)
    }
}
