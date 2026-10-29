// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

@MainActor
final class RoundedButtonView: UIButton {
    private enum Metrics {
        static let borderWidth: CGFloat = 1
        static let horizontalPadding: CGFloat = 20
        static let highlightAlpha: CGFloat = 0.1
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureBorder()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureBorder()
    }

    // Registered events affect this button’s intrinsic size, unlike a standard UIButton.
    override func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        super.addTarget(target, action: action, for: controlEvents)
        invalidateIntrinsicContentSize()
    }

    override func removeTarget(_ target: Any?, action: Selector?, for controlEvents: UIControl.Event) {
        super.removeTarget(target, action: action, for: controlEvents)
        invalidateIntrinsicContentSize()
    }

    override func addAction(_ action: UIAction, for controlEvents: UIControl.Event) {
        super.addAction(action, for: controlEvents)
        invalidateIntrinsicContentSize()
    }

    override func removeAction(_ action: UIAction, for controlEvents: UIControl.Event) {
        super.removeAction(action, for: controlEvents)
        invalidateIntrinsicContentSize()
    }

    override func removeAction(identifiedBy actionIdentifier: UIAction.Identifier, for controlEvents: UIControl.Event) {
        super.removeAction(identifiedBy: actionIdentifier, for: controlEvents)
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = configuration == nil ? ceil(bounds.height / 2) : 0
        updateStateAppearance()
    }

    override var intrinsicContentSize: CGSize {
        guard !allControlEvents.isEmpty else { return .zero }
        var size = super.intrinsicContentSize
        let hasContent =
            !(currentTitle ?? "").isEmpty || !(currentAttributedTitle?.string ?? "").isEmpty
            || currentImage != nil || !(configuration?.title ?? "").isEmpty
            || configuration?.image != nil || !(configuration?.subtitle ?? "").isEmpty
            || configuration?.showsActivityIndicator == true
        guard hasContent else { return .zero }
        if configuration == nil { size.width += Metrics.horizontalPadding }
        return size
    }

    // UIKit may treat nil as unchanged after removing a configuration, but our empty size must refresh.
    override func setTitle(_ title: String?, for state: UIControl.State) {
        super.setTitle(title, for: state)
        invalidateIntrinsicContentSize()
    }

    override func setAttributedTitle(_ title: NSAttributedString?, for state: UIControl.State) {
        super.setAttributedTitle(title, for: state)
        invalidateIntrinsicContentSize()
    }

    override func setImage(_ image: UIImage?, for state: UIControl.State) {
        super.setImage(image, for: state)
        invalidateIntrinsicContentSize()
    }

    override func setTitleColor(_ color: UIColor?, for state: UIControl.State) {
        super.setTitleColor(color, for: state)
        updateStateAppearance()
    }

    override func updateConfiguration() {
        super.updateConfiguration()
        updateContentState()
    }

    override var isHighlighted: Bool {
        didSet { updateContentState() }
    }

    override var isSelected: Bool {
        didSet { updateContentState() }
    }

    override var isEnabled: Bool {
        didSet { updateContentState() }
    }

    private func updateContentState() {
        invalidateIntrinsicContentSize()
        updateStateAppearance()
    }

    private func configureBorder() {
        registerForTraitChanges(UITraitCollection.systemTraitsAffectingColorAppearance) {
            (button: RoundedButtonView, _) in
            button.updateStateAppearance()
        }
        updateStateAppearance()
    }

    private func updateStateAppearance() {
        layer.borderWidth = configuration == nil ? Metrics.borderWidth : 0
        guard configuration == nil else {
            layer.borderColor = nil
            backgroundColor = .clear
            return
        }
        let color = currentTitleColor
        layer.borderColor = color.resolvedColor(with: traitCollection).cgColor
        backgroundColor = isHighlighted ? color.withAlphaComponent(Metrics.highlightAlpha) : .clear
    }
}
