// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

@MainActor
final class HUDRoundedButtonView: UIButton {
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

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = ceil(bounds.height / 2)
        updateStateAppearance()
    }

    override var intrinsicContentSize: CGSize {
        guard !allControlEvents.isEmpty, !(title(for: .normal) ?? "").isEmpty else { return .zero }
        var size = super.intrinsicContentSize
        size.width += Metrics.horizontalPadding
        return size
    }

    override func setTitleColor(_ color: UIColor?, for state: UIControl.State) {
        super.setTitleColor(color, for: state)
        updateStateAppearance()
    }

    override var isHighlighted: Bool {
        didSet { updateStateAppearance() }
    }

    override var isSelected: Bool {
        didSet { updateStateAppearance() }
    }

    override var isEnabled: Bool {
        didSet { updateStateAppearance() }
    }

    private func configureBorder() {
        layer.borderWidth = Metrics.borderWidth
        registerForTraitChanges(UITraitCollection.systemTraitsAffectingColorAppearance) {
            (button: HUDRoundedButtonView, _) in
            button.updateStateAppearance()
        }
        updateStateAppearance()
    }

    private func updateStateAppearance() {
        let color = currentTitleColor
        layer.borderColor = color.resolvedColor(with: traitCollection).cgColor
        backgroundColor = isHighlighted ? color.withAlphaComponent(Metrics.highlightAlpha) : .clear
    }
}
