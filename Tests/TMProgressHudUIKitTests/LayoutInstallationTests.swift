import Testing
import UIKit
@testable import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct LayoutInstallationTests {
    @Test func changingBezelAndContainerDetachesOnlyOwnedConstraints() {
        let layout = HUDLayout()
        let firstContainer = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let firstBezel = makeBezel(in: firstContainer)
        let firstLabel = makeLabel(in: firstBezel)
        let configuration = HUDLayout.Configuration(
            layout: .init(), minimumSize: CGSize(width: 100, height: 100), isSquare: true)
        layout.update(container: firstContainer, bezel: firstBezel, content: [firstLabel], configuration: configuration)
        firstContainer.layoutIfNeeded()
        let previousConstraints = firstContainer.constraints + firstBezel.constraints
        let clientConstraint = firstBezel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40)
        clientConstraint.isActive = true
        let secondBezel = makeBezel(in: firstContainer)
        let secondLabel = makeLabel(in: secondBezel)
        layout.update(
            container: firstContainer, bezel: secondBezel, content: [secondLabel], configuration: configuration)
        firstContainer.layoutIfNeeded()
        #expect(previousConstraints.allSatisfy { !$0.isActive })
        #expect(clientConstraint.isActive)
        #expect(secondBezel.bounds.width >= 100)
        #expect(secondBezel.bounds.width == secondBezel.bounds.height)
        #expect(secondBezel.frame.midX == firstContainer.bounds.midX)
        let secondContainer = UIView(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        secondContainer.addSubview(secondBezel)
        layout.update(
            container: secondContainer, bezel: secondBezel, content: [secondLabel], configuration: configuration)
        secondContainer.layoutIfNeeded()
        #expect(secondBezel.bounds.width >= 100)
        #expect(secondBezel.bounds.width == secondBezel.bounds.height)
        #expect(secondBezel.frame.midX == secondContainer.bounds.midX)
        #expect(secondBezel.frame.midY == secondContainer.bounds.midY)
        #expect(clientConstraint.isActive)
    }

    private func makeBezel(in container: UIView) -> UIView {
        let bezel = UIView()
        bezel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bezel)
        return bezel
    }

    private func makeLabel(in bezel: UIView) -> UILabel {
        let label = UILabel()
        label.text = "Loading"
        label.translatesAutoresizingMaskIntoConstraints = false
        bezel.addSubview(label)
        return label
    }
}
