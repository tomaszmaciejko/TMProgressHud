import Testing
import UIKit
import TMProgressHudUIKit

@MainActor
private final class ReadbackLegacyView: UIView {
    @objc var progress: Float = 0
}

@MainActor
private final class ReadbackOverrideHud: TMProgressHud {
    let suppliedView = UIView()

    override var mode: TMProgressHudMode {
        get { .customView }
        set { super.mode = newValue }
    }

    override var customView: UIView? {
        get { suppliedView }
        set { super.customView = newValue }
    }
}

@Suite(.serialized)
@MainActor
struct ContentReadbackTests {
    @Test func savedBuiltInSelectionsRestoreTheChosenIndicator() throws {
        let hud = TMProgressHud(frame: .zero)
        let selections: [(TMProgressHudContent, TMProgressHudMode)] = [
            (.activity, .indeterminate), (.outlinedCircle, .determinate),
            (.ring, .annularDeterminate), (.bar, .determinateHorizontalBar), (.text, .text),
        ]
        for (content, expectedMode) in selections {
            hud.setContent(content)
            let saved = try #require(hud.contentConfiguration)
            hud.setContent(.activity)
            hud.setContent(saved)
            #expect(hud.mode == expectedMode)
            #expect(hud.customView == nil)
        }
    }

    @Test(arguments: [false, true])
    func savedCustomContentRestoresIdentityAndForwardingPolicy(legacy: Bool) throws {
        let hud = TMProgressHud(frame: .zero)
        let view = ReadbackLegacyView()
        hud.setContent(legacy ? .legacyCustom(view) : .custom(view))
        let saved = try #require(hud.contentConfiguration)
        switch saved {
        case .custom(let selected):
            #expect(!legacy)
            #expect(selected === view)
        case .legacyCustom(let selected):
            #expect(legacy)
            #expect(selected === view)
        default: Issue.record("Custom selection was not preserved")
        }
        hud.setContent(.text)
        hud.setProgressSource(.manual(0.75))
        hud.setContent(saved)
        #expect(hud.customView === view)
        #expect(view.superview === hud.bezelView)
        #expect(view.progress == (legacy ? 0.75 : 0))
    }

    @Test func emptyCompatibilityCustomModeHasNoCompleteSelection() {
        let hud = TMProgressHud(frame: .zero)
        hud.mode = .customView
        #expect(hud.contentConfiguration == nil)
        #expect(hud.mode == .customView)
        #expect(hud.customView == nil)
        hud.setContent(.text)
        guard case .text? = hud.contentConfiguration else {
            Issue.record("Text mode must remain representable")
            return
        }
    }

    @Test func contentReadbackRespectsPublicGetterOverrides() {
        let hud = ReadbackOverrideHud(frame: .zero)
        guard case .legacyCustom(let selected)? = hud.contentConfiguration else {
            Issue.record("Compatibility getters must define the effective selection")
            return
        }
        #expect(selected === hud.suppliedView)
    }
}
