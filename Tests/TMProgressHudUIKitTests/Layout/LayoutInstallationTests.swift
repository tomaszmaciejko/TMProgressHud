import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class LayoutInvalidationView: UIView {
    var invalidations = 0

    override func setNeedsUpdateConstraints() {
        invalidations += 1
        super.setNeedsUpdateConstraints()
    }
}

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

    @Test func identicalContentInvalidatesOnlyItsNewContainer() {
        let layout = HUDLayout()
        let first = LayoutInvalidationView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let second = LayoutInvalidationView(frame: first.bounds)
        let bezel = makeBezel(in: first)
        let label = makeLabel(in: bezel)
        let configuration = HUDLayout.Configuration(layout: .init(), minimumSize: .zero, isSquare: false)
        layout.update(container: first, bezel: bezel, content: [label], configuration: configuration)
        second.addSubview(bezel)
        layout.update(container: second, bezel: bezel, content: [label], configuration: configuration)
        first.invalidations = 0
        second.invalidations = 0
        label.isHidden = true
        #expect(first.invalidations == 0)
        #expect(second.invalidations == 1)
    }

    @Test func repeatedUpdatesObserveOnceAndReplacedContentStopsInvalidating() {
        let layout = HUDLayout()
        let container = LayoutInvalidationView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let bezel = makeBezel(in: container)
        let label = makeLabel(in: bezel)
        let configuration = HUDLayout.Configuration(layout: .init(), minimumSize: .zero, isSquare: false)
        for _ in 0..<3 {
            layout.update(container: container, bezel: bezel, content: [label], configuration: configuration)
        }
        container.invalidations = 0
        label.isHidden = true
        #expect(container.invalidations == 1)
        let replacement = makeLabel(in: bezel)
        layout.update(container: container, bezel: bezel, content: [replacement], configuration: configuration)
        container.invalidations = 0
        label.isHidden = false
        #expect(container.invalidations == 0)
        replacement.isHidden = true
        #expect(container.invalidations == 1)
    }

    @Test func replacingBezelRemovesOnlyOwnedSpacingViewsFromThePreviousBezel() {
        let layout = HUDLayout()
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let previousBezel = makeBezel(in: container)
        let previousLabel = makeLabel(in: previousBezel)
        let hiddenClientView = UIView()
        hiddenClientView.isHidden = true
        previousBezel.addSubview(hiddenClientView)
        let configuration = HUDLayout.Configuration(layout: .init(), minimumSize: .zero, isSquare: false)
        layout.update(
            container: container, bezel: previousBezel, content: [previousLabel], configuration: configuration)
        let ownedSpacingViews = previousBezel.subviews.filter { $0 !== previousLabel && $0 !== hiddenClientView }
        #expect(!ownedSpacingViews.isEmpty)
        let replacementBezel = makeBezel(in: container)
        let replacementLabel = makeLabel(in: replacementBezel)
        layout.update(
            container: container, bezel: replacementBezel, content: [replacementLabel], configuration: configuration)
        #expect(ownedSpacingViews.allSatisfy { $0.superview !== previousBezel })
        #expect(previousLabel.superview === previousBezel)
        #expect(hiddenClientView.superview === previousBezel)
        #expect(replacementLabel.superview === replacementBezel)
    }

    @Test func preparingInstallationLeavesHierarchyAndConstraintsUnchangedUntilActivation() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let bezel = makeBezel(in: container)
        let label = makeLabel(in: bezel)
        let clientConstraint = bezel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        clientConstraint.isActive = true
        let originalSubviews = bezel.subviews.map(ObjectIdentifier.init)
        let originalConstraints = Set((container.constraints + bezel.constraints).map(ObjectIdentifier.init))
        let installation = HUDLayoutInstallation(container: container, bezel: bezel, visibleContent: [label])
        #expect(bezel.subviews.map(ObjectIdentifier.init) == originalSubviews)
        #expect(Set((container.constraints + bezel.constraints).map(ObjectIdentifier.init)) == originalConstraints)
        installation.activate()
        installation.update(
            visibleContent: [label],
            configuration: .init(layout: .init(), minimumSize: CGSize(width: 100, height: 100), isSquare: true))
        container.layoutIfNeeded()
        #expect(bezel.bounds.width >= 100)
        #expect(bezel.bounds.width == bezel.bounds.height)
        #expect(label.superview === bezel)
        installation.deactivate()
        #expect(clientConstraint.isActive)
        #expect(bezel.subviews.map(ObjectIdentifier.init) == originalSubviews)
        #expect(Set((container.constraints + bezel.constraints).map(ObjectIdentifier.init)) == originalConstraints)
    }

    @Test func preparedInstallationDoesNotRetainItsContainerOrBezel() {
        weak var releasedContainer: UIView?
        weak var releasedBezel: UIView?
        let installation = autoreleasepool {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
            let bezel = makeBezel(in: container)
            let label = makeLabel(in: bezel)
            releasedContainer = container
            releasedBezel = bezel
            return HUDLayoutInstallation(container: container, bezel: bezel, visibleContent: [label])
        }
        #expect(releasedContainer == nil)
        #expect(releasedBezel == nil)
        installation.activate()
        installation.update(
            visibleContent: [], configuration: .init(layout: .init(), minimumSize: .zero, isSquare: false))
        installation.deactivate()
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
