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
            applyAnimationState(isAppearing: true, type: animationType)
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
        if motionSettings.shouldReduceMotion {
            resolvedType = .fade
        } else if type == .zoom {
            resolvedType = isAppearing ? .zoomIn : .zoomOut
        } else {
            resolvedType = type
        }
        let small = CGAffineTransform(scaleX: HUDMetrics.Animation.reducedScale, y: HUDMetrics.Animation.reducedScale)
        let large = CGAffineTransform(scaleX: HUDMetrics.Animation.enlargedScale, y: HUDMetrics.Animation.enlargedScale)
        if isAppearing && bezelView.alpha == 0 {
            if resolvedType == .zoomIn {
                bezelView.transform = small
            } else if resolvedType == .zoomOut {
                bezelView.transform = large
            }
        }
        UIView.animate(
            springDuration: HUDMetrics.Animation.perceivedDuration, bounce: 0,
            initialSpringVelocity: 0, delay: 0, options: .beginFromCurrentState,
            animations: {
                self.applyAnimationState(isAppearing: isAppearing, type: resolvedType)
            },
            completion: completion
        )
    }

    private func applyAnimationState(isAppearing: Bool, type: TMProgressHudAnimation) {
        let scale: CGFloat
        if isAppearing {
            scale = 1
        } else {
            switch type {
            case .zoomIn: scale = HUDMetrics.Animation.enlargedScale
            case .zoomOut: scale = HUDMetrics.Animation.reducedScale
            default: scale = 1
            }
        }
        bezelView.transform = CGAffineTransform(scaleX: scale, y: scale)
        bezelView.alpha = isAppearing ? 1 : 0
        backgroundView.alpha = isAppearing ? 1 : 0
    }

    func finishPresentation(completion: (@MainActor () -> Void)?) {
        let compatibilityCompletion = completionBlock
        let notificationDelegate = delegate
        completionBlock = nil
        updateProgressObservation()
        alpha = 0
        if removeFromSuperViewOnHide { removeFromSuperview() }
        completion?()
        compatibilityCompletion?()
        notificationDelegate?.hudWasHidden?(self)
    }

    // MARK: - Motion effects

    func updateBezelMotionEffects() {
        if areDefaultMotionEffectsEnabled && !motionSettings.shouldReduceMotion {
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
        effect.maximumRelativeValue = HUDMetrics.Animation.motionOffset
        effect.minimumRelativeValue = -HUDMetrics.Animation.motionOffset
        return effect
    }
}
