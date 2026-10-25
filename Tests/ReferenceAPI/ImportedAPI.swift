import UIKit

@MainActor
func verifyImportedAPI(in host: UIView) {
    let hud = MBProgressHUD.showAdded(to: host, animated: false)
    _ = MBProgressHUD.forView(host)
    _ = MBProgressHUD.hide(for: host, animated: false)
    let configured = MBProgressHUD(view: host)
    configured.show(animated: false)
    configured.hide(animated: false)
    hud.hide(animated: false, afterDelay: 0)
    hud.mode = .indeterminate
    hud.animationType = .zoomOut
    hud.isSquare = true
    hud.areDefaultMotionEffectsEnabled = false
    hud.graceTime = 0
    hud.minShowTime = 0
    hud.removeFromSuperViewOnHide = true
    hud.contentColor = nil
    hud.offset = .zero
    hud.margin = 20
    hud.minSize = .zero
    hud.progress = 0.5
    hud.progressObject = Progress(totalUnitCount: 10)
    hud.customView = UIView()
    hud.label.text = "Loading"
    hud.detailsLabel.text = "Details"
    _ = hud.button
    hud.bezelView.style = .blur
    hud.backgroundView.color = .clear
    #if os(tvOS)
        hud.bezelView.blurEffectStyle = .regular
    #else
        hud.bezelView.blurEffectStyle = .systemThickMaterial
    #endif
    hud.completionBlock = {}
    hud.delegate = nil
    let round = MBRoundProgressView()
    round.isAnnular = true
    round.progress = 0.5
    round.progressTintColor = .white
    round.backgroundTintColor = .clear
    let bar = MBBarProgressView()
    bar.progress = 0.5
    bar.progressColor = .white
    bar.progressRemainingColor = .clear
    bar.lineColor = .white
    _ = MBProgressMaxOffset
}

@MainActor
private final class ReferenceHUDSubclass: MBProgressHUD {}

@MainActor
private final class ReferenceDelegate: NSObject, MBProgressHUDDelegate {
    nonisolated func hudWasHidden(_ hud: MBProgressHUD) {}
}

@MainActor
private func verifySubclassAndOptionalDelegate(in host: UIView) {
    let subclass: ReferenceHUDSubclass = ReferenceHUDSubclass.showAdded(to: host, animated: false)
    let delegate = ReferenceDelegate()
    subclass.delegate = delegate
    subclass.delegate?.hudWasHidden?(subclass)
}
