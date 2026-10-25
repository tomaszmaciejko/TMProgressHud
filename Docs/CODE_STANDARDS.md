# Code standards

Readability takes priority over cleverness. Follow the Swift API Design Guidelines and write code, comments and test names in English.

## Structure

- Use descriptive names and one primary type per file. Avoid generic `Manager`, `Helper` and `Utils` types.
- Apply SOLID where it clarifies responsibilities. Introduce protocols at real boundaries, rather than for every type.
- Avoid duplicated behavior, speculative abstractions and unnecessary state.
- Name domain, layout and timing constants with their meaning and units. Explain non-obvious formulas. Ordinary literals such as zero need no wrapper.
- Default to private or internal. Public APIs need documentation, deliberate defaults and clear ownership.

The 1.0 port retains the original public names and subclassing contract. Its facade is split into content, layout and lifecycle files while keeping shared presentation state together.

## Safety

Use Swift 6 isolation; UI state and callbacks belong to the main actor. Every timer and observer needs an explicit owner. Preserve the reference timing and callback behavior when changing this port.

No force unwraps, forced casts, force try or hidden concurrency escapes. Handle meaningful failures explicitly. Do not silence compiler warnings or add global mutable state. Discuss any necessary exception in the pull request with a specific safety argument.

## Formatting and review

`swift-format` from Xcode owns formatting and documentation checks: four spaces and a 120-column target. SwiftLint checks production safety and structural metrics. Its version is pinned in `.swiftlint-version`; `.swiftlint.yml` explicitly selects rules without overlapping cosmetic formatting rules. `Scripts/check.sh` runs both tools.

SwiftLint enforces production limits of 350 file lines, 40 function-body lines and complexity 8, using its standard metric definitions. Function-body counts exclude blank and comment lines. Type size (200 nonblank lines), test-file size (500 lines) and test-function size (80 lines) remain manual review triggers. Explain necessary deviations rather than splitting cohesive code to satisfy a number. The two regex rules in `.swiftlint.yml` reject runtime traps and concurrency escapes while ignoring comments and strings; there is no separate custom linter.

Tests should assert observable outcomes, including boundary values and repeated operations. Require 100% executable production line coverage with no blanket exclusions. Any proposed exception must identify the exact line, reason and source hash in `Scripts/coverage-exceptions.json`; there are currently none. Compiler-unmapped declarations are separately recorded in `Scripts/coverage-unmapped.json`.
