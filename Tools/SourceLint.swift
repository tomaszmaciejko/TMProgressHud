import Foundation
import SwiftParser
import SwiftSyntax

final class DecisionCounter: SyntaxVisitor {
    var count = 0
    init() { super.init(viewMode: .sourceAccurate) }
    override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind { count += 1; return .visitChildren }
    override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind { count += 1; return .visitChildren }
    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind { count += 1; return .visitChildren }
    override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind { count += 1; return .visitChildren }
    override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind { count += 1; return .visitChildren }
    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind { count += 1; return .visitChildren }
    override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind { count += 1; return .visitChildren }
    override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind { count -= 1; return .visitChildren }
    override func visit(_ node: TernaryExprSyntax) -> SyntaxVisitorContinueKind { count += 1; return .visitChildren }
}

final class SafetyVisitor: SyntaxVisitor {
    let path: String
    let converter: SourceLocationConverter
    var findings: [String] = []

    init(path: String, tree: SourceFileSyntax) {
        self.path = path
        converter = SourceLocationConverter(fileName: path, tree: tree)
        super.init(viewMode: .sourceAccurate)
    }

    func report(_ node: some SyntaxProtocol, _ message: String) {
        let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        findings.append("\(path):\(location.line): error: \(message)")
    }

    override func visit(_ node: AsExprSyntax) -> SyntaxVisitorContinueKind {
        if node.questionOrExclamationMark?.text == "!" {
            report(node, "Use a checked cast and define the failure outcome.")
        }
        return .visitChildren
    }

    override func visit(_ node: UnresolvedAsExprSyntax) -> SyntaxVisitorContinueKind {
        if node.questionOrExclamationMark?.text == "!" {
            report(node, "Use a checked cast and define the failure outcome.")
        }
        return .visitChildren
    }

    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        let text = node.trimmedDescription
        if text.contains("unchecked") || text.contains("preconcurrency") {
            report(node, "Concurrency escape requires a precise approved ADR and lint allowlist.")
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if ["fatalError", "preconditionFailure"].contains(node.calledExpression.trimmedDescription) {
            report(node, "Do not trap on caller input; define an explicit supported outcome.")
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let body = node.body {
            let start = converter.location(for: body.positionAfterSkippingLeadingTrivia).line
            let end = converter.location(for: body.endPositionBeforeTrailingTrivia).line
            let decisions = DecisionCounter()
            decisions.walk(body)
            let booleanBranches = body.tokens(viewMode: .sourceAccurate).filter { ["&&", "||"].contains($0.text) }.count
            let complexity = 1 + decisions.count + booleanBranches
            if complexity > 8 {
                report(node, "Function decision complexity exceeds 8; split cohesive responsibilities.")
            }
            if end - start > 40 {
                report(node, "Function exceeds 40 physical lines; review responsibility or record a scoped exception.")
            }
        }
        return .visitChildren
    }
}

var violations: [String] = []
for path in CommandLine.arguments.dropFirst() {
    let source = try String(contentsOfFile: path, encoding: .utf8)
    if source.split(separator: "\n").filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }).count > 350 {
        violations.append("\(path):1: error: Production file exceeds 350 nonblank lines.")
    }
    let tree = Parser.parse(source: source)
    let visitor = SafetyVisitor(path: path, tree: tree)
    visitor.walk(tree)
    violations += visitor.findings
}
for violation in violations { print(violation) }
if !violations.isEmpty { exit(1) }
