import Foundation
import Testing
import UIKit
@testable import TMProgressHudUIKit

@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct ProgressBindingTests {
    @Test func assigningProgressDoesNotRetainUnshownHUD() {
        weak var reference: TMProgressHud?
        autoreleasepool {
            let hud = TMProgressHud(frame: .zero)
            hud.progressObject = Progress(totalUnitCount: 100)
            reference = hud
        }
        #expect(reference == nil)
        reference?.hide(animated: false)
    }

    @Test func detachedHUDWithProgressIsReleased() {
        weak var reference: TMProgressHud?
        autoreleasepool {
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
            let hud = TMProgressHud.showAdded(to: host, animated: false)
            hud.progressObject = Progress(totalUnitCount: 100)
            reference = hud
            hud.removeFromSuperview()
        }
        #expect(reference == nil)
        reference?.hide(animated: false)
    }
    @Test func inactiveBindingReadsLatestValueWhenStarted() {
        var values: [Float] = []
        let binding = ProgressBinding { values.append($0) }
        let source = Progress(totalUnitCount: 100)
        source.completedUnitCount = 25
        binding.replace(with: source)
        binding.replace(with: source)
        #expect(binding.source === source)
        #expect(values.isEmpty)
        binding.start()
        binding.start()
        #expect(values == [0.25])
        binding.stop()
        binding.stop()
        source.completedUnitCount = 50
        #expect(values == [0.25])
        binding.start()
        #expect(values == [0.25, 0.5])
        binding.replace(with: nil)
        #expect(binding.source == nil)
        binding.stop()
        binding.start()
        binding.stop()
    }

    @Test func backgroundUpdatesArriveOnMainActor() async throws {
        let source = Progress(totalUnitCount: 100)
        let completed = CallbackExpectation()
        var values: [Float] = []
        let binding = ProgressBinding { value in
            #expect(Thread.isMainThread)
            values.append(value)
            if value == 0.5 {
                completed.signal()
            }
        }
        binding.replace(with: source)
        binding.start()
        defer { binding.stop() }
        DispatchQueue.global().async { source.completedUnitCount = 50 }
        try await completed.wait()
        #expect(values.last == 0.5)
    }

    @Test func burstsCoalesceToLatestValue() async throws {
        let source = Progress(totalUnitCount: 1000)
        let completed = CallbackExpectation()
        var values: [Float] = []
        let binding = ProgressBinding { value in
            values.append(value)
            if value == 1 {
                completed.signal()
            }
        }
        binding.replace(with: source)
        binding.start()
        defer { binding.stop() }
        for count in 1...1000 { source.completedUnitCount = Int64(count) }
        try await completed.wait()
        #expect(values == [0, 1])
    }

    @Test func replacedSourcesCannotDeliverQueuedValues() async throws {
        let first = Progress(totalUnitCount: 100)
        let second = Progress(totalUnitCount: 100)
        second.completedUnitCount = 80
        let completed = CallbackExpectation()
        var values: [Float] = []
        let binding = ProgressBinding { value in
            values.append(value)
            if value == 0.9 {
                completed.signal()
            }
        }
        binding.replace(with: first)
        binding.start()
        defer { binding.stop() }
        first.completedUnitCount = 25
        binding.replace(with: second)
        first.completedUnitCount = 50
        second.completedUnitCount = 90
        try await completed.wait()
        #expect(values == [0, 0.8, 0.9])
    }

    @Test func stopAndRestartDiscardQueuedValues() async throws {
        let source = Progress(totalUnitCount: 100)
        let completed = CallbackExpectation()
        var values: [Float] = []
        let binding = ProgressBinding { value in
            values.append(value)
            if value == 0.8 {
                completed.signal()
            }
        }
        binding.replace(with: source)
        binding.start()
        defer { binding.stop() }
        source.completedUnitCount = 50
        binding.stop()
        source.completedUnitCount = 75
        binding.start()
        source.completedUnitCount = 80
        try await completed.wait()
        #expect(values == [0, 0.75, 0.8])
    }

    @Test func childProgressUpdatesParentFraction() async throws {
        let parent = Progress(totalUnitCount: 100)
        let child = Progress(totalUnitCount: 10)
        parent.addChild(child, withPendingUnitCount: 100)
        let completed = CallbackExpectation()
        let binding = ProgressBinding { value in
            if value == 0.5 {
                completed.signal()
            }
        }
        binding.replace(with: parent)
        binding.start()
        defer { binding.stop() }
        DispatchQueue.global().async { child.completedUnitCount = 5 }
        try await completed.wait()
        #expect(parent.fractionCompleted == 0.5)
        #expect(parent.completedUnitCount == 0)
    }

    @Test func activeBindingAndSourceAreReleased() async {
        weak var bindingReference: ProgressBinding?
        weak var sourceReference: Progress?
        autoreleasepool {
            let source = Progress(totalUnitCount: 100)
            let binding = ProgressBinding { _ in }
            binding.replace(with: source)
            binding.start()
            bindingReference = binding
            sourceReference = source
        }
        #expect(bindingReference == nil)
        #expect(sourceReference == nil)
        await Task.yield()
    }

    @Test func detachingWholeHostReleasesActiveHUD() throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let root = try #require(window.rootViewController?.view)
        let source = Progress(totalUnitCount: 100)
        source.completedUnitCount = 25
        weak var reference: TMProgressHud?
        autoreleasepool {
            let host = UIView(frame: root.bounds)
            root.addSubview(host)
            let hud = TMProgressHud.showAdded(to: host, animated: false)
            hud.progressObject = source
            #expect(hud.progress == 0.25)
            reference = hud
            host.removeFromSuperview()
        }
        #expect(reference == nil)
    }

    @Test func hiddenAndDetachedHUDStopsAndRefreshesOnReturn() async throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        let source = Progress(totalUnitCount: 100)
        hud.progressObject = source
        let completed = CallbackExpectation()
        let observation = hud.observe(\.progress, options: [.new]) { _, change in
            if change.newValue == 0.5 { completed.signal() }
        }
        defer { observation.invalidate() }
        DispatchQueue.global().async { source.completedUnitCount = 50 }
        try await completed.wait()
        observation.invalidate()
        #expect(hud.progress == 0.5)
        hud.hide(animated: false)
        source.completedUnitCount = 75
        #expect(hud.progress == 0.5)
        host.addSubview(hud)
        hud.show(animated: false)
        #expect(hud.progress == 0.75)
        hud.removeFromSuperview()
        source.completedUnitCount = 90
        #expect(hud.progress == 0.75)
        host.addSubview(hud)
        #expect(hud.progress == 0.9)
    }

    @Test func gracePeriodDoesNotStartObservation() throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(view: host)
        host.addSubview(hud)
        hud.setTimingEnvironment(time.environment)
        hud.graceTime = 5
        let source = Progress(totalUnitCount: 100)
        hud.progressObject = source
        hud.show(animated: false)
        source.completedUnitCount = 25
        #expect(hud.progress == 0)
        time.actions.last?.fire()
        #expect(hud.progress == 0.25)
        hud.hide(animated: false)
    }
}
