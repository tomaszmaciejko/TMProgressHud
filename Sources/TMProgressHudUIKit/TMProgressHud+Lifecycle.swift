// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

extension TMProgressHud: HUDPresentationHost {
    func showPresentation(animated: Bool) {
        bezelView.layer.removeAllAnimations()
        backgroundView.layer.removeAllAnimations()
        alpha = 1
        updateProgressObservation()
        updateBezelMotionEffects()
        if animated {
            animate(isAppearing: true, type: animationType, completion: nil)
        } else {
            bezelView.alpha = 1
            backgroundView.alpha = 1
        }
    }

    func hidePresentation(animated: Bool, completion: @escaping @MainActor () -> Void) {
        updateProgressObservation()
        if animated {
            animate(isAppearing: false, type: animationType) { _ in completion() }
        } else {
            bezelView.alpha = 0
            backgroundView.alpha = 1
            completion()
        }
    }

    func animate(isAppearing: Bool, type: TMProgressHudAnimation, completion: ((Bool) -> Void)?) {
        let resolvedType: TMProgressHudAnimation
        if type == .zoom {
            resolvedType = isAppearing ? .zoomIn : .zoomOut
        } else {
            resolvedType = type
        }
        let small = CGAffineTransform(scaleX: HUDMetrics.reducedScale, y: HUDMetrics.reducedScale)
        let large = CGAffineTransform(scaleX: HUDMetrics.enlargedScale, y: HUDMetrics.enlargedScale)
        if isAppearing && bezelView.alpha == 0 {
            if resolvedType == .zoomIn {
                bezelView.transform = small
            } else if resolvedType == .zoomOut {
                bezelView.transform = large
            }
        }
        UIView.animate(
            springDuration: HUDMetrics.animationPerceivedDuration, bounce: 0,
            initialSpringVelocity: 0, delay: 0, options: .beginFromCurrentState,
            animations: {
                self.applyAnimationState(isAppearing: isAppearing, type: resolvedType, small: small, large: large)
            },
            completion: completion
        )
    }

    private func applyAnimationState(
        isAppearing: Bool, type: TMProgressHudAnimation,
        small: CGAffineTransform, large: CGAffineTransform
    ) {
        if isAppearing {
            bezelView.transform = .identity
        } else if type == .zoomIn {
            bezelView.transform = large
        } else if type == .zoomOut {
            bezelView.transform = small
        }
        bezelView.alpha = isAppearing ? 1 : 0
        backgroundView.alpha = isAppearing ? 1 : 0
    }

    func finishPresentation() {
        updateProgressObservation()
        alpha = 0
        if removeFromSuperViewOnHide { removeFromSuperview() }
        completionBlock?()
        delegate?.hudWasHidden?(self)
    }

    // MARK: - Motion effects

    func updateBezelMotionEffects() {
        if areDefaultMotionEffectsEnabled {
            guard bezelMotionEffects == nil else { return }
            let horizontal = motionEffect(key: "center.x", type: .tiltAlongHorizontalAxis)
            let vertical = motionEffect(key: "center.y", type: .tiltAlongVerticalAxis)
            let group = UIMotionEffectGroup()
            group.motionEffects = [horizontal, vertical]
            bezelMotionEffects = group
            bezelView.addMotionEffect(group)
        } else if let effects = bezelMotionEffects {
            bezelMotionEffects = nil
            bezelView.removeMotionEffect(effects)
        }
    }

    private func motionEffect(key: String, type: UIInterpolatingMotionEffect.EffectType) -> UIInterpolatingMotionEffect
    {
        let effect = UIInterpolatingMotionEffect(keyPath: key, type: type)
        effect.maximumRelativeValue = HUDMetrics.motionOffset
        effect.minimumRelativeValue = -HUDMetrics.motionOffset
        return effect
    }
}
