import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class SwiftProgressView: UIView, TMProgressHudProgressReporting {
    var progress: Float = 0
}

@Suite(.serialized)
@MainActor
struct IndicatorContractTests {
    @Test func nativeUIKitProgressViewReceivesProgressAndKeepsItsWidth() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        let native = UIProgressView(progressViewStyle: .default)
        let width: CGFloat = 120
        native.widthAnchor.constraint(equalToConstant: width).isActive = true
        hud.customView = native
        hud.mode = .customView
        hud.progress = 0.25
        #expect(native.progress == 0.25)
        hud.progress = 0.75
        host.layoutIfNeeded()
        #expect(native.progress == 0.75)
        #expect(native.frame.width == width)
        #expect(native.superview === hud.bezelView)
        hud.mode = .determinateHorizontalBar
        #expect(native.superview == nil)
        hud.progress = 0.5
        hud.mode = .customView
        #expect(native.progress == 0.5)
        #expect(native.superview === hud.bezelView)
    }

    @Test func nativeSwiftCustomViewReceivesUnnormalizedProgress() {
        let hud = TMProgressHud(frame: .zero)
        let custom = SwiftProgressView()
        #expect(!custom.responds(to: NSSelectorFromString("setProgress:")))
        hud.progress = 0.25
        hud.customView = custom
        hud.mode = .customView
        #expect(custom.progress == 0.25)
        hud.progress = -0.5
        #expect(custom.progress == -0.5)
        hud.progress = .nan
        #expect(custom.progress.isNaN)
        hud.mode = .text
        hud.progress = 1
        #expect(custom.progress.isNaN)
        hud.mode = .customView
        #expect(custom.progress == 1)
    }

    @Test func builtInViewsKeepTypedBehaviorAsCustomContent() {
        let hud = TMProgressHud(frame: .zero)
        hud.contentColor = .red
        hud.mode = .customView
        let round = TMRoundProgressView()
        round.isAnnular = true
        hud.customView = round
        hud.progress = 0.5
        #expect(round.progress == 0.5)
        #expect(round.isAnnular)
        #expect(round.progressTintColor == .red)
        hud.mode = .determinate
        #expect(hud.indicator === round)
        #expect(!round.isAnnular)
        hud.mode = .customView
        let bar = TMBarProgressView()
        hud.customView = bar
        #expect(bar.progress == 0.5)
        #expect(bar.lineColor == .red)
        let spinner = UIActivityIndicatorView(style: .medium)
        hud.customView = spinner
        #expect(spinner.color == .red)
        hud.mode = .indeterminate
        #expect(hud.indicator === spinner)
        hud.progress = 1
        #expect(hud.indicator === spinner)
    }

    @Test func plainCustomViewHasNoProgressContractAndPreservesTintWithoutBulkColor() {
        let hud = TMProgressHud(frame: .zero)
        hud.contentColor = nil
        let custom = UIView()
        custom.tintColor = .green
        hud.customView = custom
        hud.mode = .customView
        hud.progress = 0.5
        #expect(hud.indicator === custom)
        #expect(custom.tintColor == .green)
        hud.contentColor = .blue
        #expect(custom.tintColor == .blue)
        hud.customView = custom
        #expect(custom.superview === hud.bezelView)
    }

    @Test func replacingCustomContentReleasesThePreviousView() {
        let hud = TMProgressHud(frame: .zero)
        hud.mode = .customView
        weak var previous: SwiftProgressView?
        autoreleasepool {
            let view = SwiftProgressView()
            previous = view
            hud.customView = view
            #expect(previous != nil)
            hud.customView = UIView()
            hud.updateConstraintsIfNeeded()
        }
        #expect(previous == nil)
    }
}
