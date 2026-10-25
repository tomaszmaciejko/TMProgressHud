// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

extension TMProgressHud {
    func handleGraceAction() {
        if !hasFinished { showUsingAnimation(useAnimation) }
    }

    func showUsingAnimation(_ animated: Bool) {
        bezelView.layer.removeAllAnimations()
        backgroundView.layer.removeAllAnimations()
        delayedHideAction = nil
        showStarted = timing.now()
        alpha = 1
        setProgressDisplayLinkEnabled(true)
        updateBezelMotionEffects()
        if animated {
            animate(in: true, type: animationType, completion: nil)
        } else {
            bezelView.alpha = 1
            backgroundView.alpha = 1
        }
    }

    func hideUsingAnimation(_ animated: Bool) {
        delayedHideAction = nil
        if animated && showStarted != nil {
            showStarted = nil
            animate(in: false, type: animationType) { _ in self.done() }
        } else {
            showStarted = nil
            bezelView.alpha = 0
            backgroundView.alpha = 1
            done()
        }
    }

    func animate(in appearing: Bool, type: TMProgressHudAnimation, completion: ((Bool) -> Void)?) {
        let resolvedType: TMProgressHudAnimation = type == .zoom ? (appearing ? .zoomIn : .zoomOut) : type
        let small = CGAffineTransform(scaleX: HUDMetrics.reducedScale, y: HUDMetrics.reducedScale)
        let large = CGAffineTransform(scaleX: HUDMetrics.enlargedScale, y: HUDMetrics.enlargedScale)
        if appearing && bezelView.alpha == 0 {
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
                self.applyAnimationState(appearing: appearing, type: resolvedType, small: small, large: large)
            },
            completion: completion
        )
    }

    private func applyAnimationState(
        appearing: Bool, type: TMProgressHudAnimation,
        small: CGAffineTransform, large: CGAffineTransform
    ) {
        if appearing {
            bezelView.transform = .identity
        } else if type == .zoomIn {
            bezelView.transform = large
        } else if type == .zoomOut {
            bezelView.transform = small
        }
        bezelView.alpha = appearing ? 1 : 0
        backgroundView.alpha = appearing ? 1 : 0
    }

    func done() {
        setProgressDisplayLinkEnabled(false)
        if hasFinished {
            alpha = 0
            if removeFromSuperViewOnHide { removeFromSuperview() }
        }
        completionBlock?()
        delegate?.hudWasHidden?(self)
    }

    func setProgressDisplayLinkEnabled(_ enabled: Bool) {
        if enabled && progressObject != nil {
            if progressDisplayLink == nil {
                let link = CADisplayLink(target: self, selector: #selector(updateProgressFromProgressObject))
                progressDisplayLink = link
            }
        } else {
            progressDisplayLink = nil
        }
    }

    @objc func updateProgressFromProgressObject() {
        if let progressObject { progress = Float(progressObject.fractionCompleted) }
    }
}
