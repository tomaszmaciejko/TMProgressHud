# Code standards

Readability takes priority over cleverness. Follow the Swift API Design Guidelines and write code, comments and test names in English.

## Structure

- Names must explain the purpose of methods, properties and local values without a supporting comment. Rename unclear concepts before documenting them.
- Document non-obvious method contracts, especially internal methods: describe effects on hierarchy, constraints or observations, ownership, isolation and required call order. Comments explain behavior beyond the name rather than repeating it.
- Use descriptive names and one primary type per file. Avoid generic `Manager`, `Helper` and `Utils` types.
- Apply SOLID where it clarifies responsibilities. Introduce protocols at real boundaries, rather than for every type.
- Avoid duplicated behavior, speculative abstractions and unnecessary state.
- Keep constants private to their consumer file unless multiple files need the same value and meaning.
- Name domain, layout and timing constants with their meaning and units. Explain non-obvious formulas. Ordinary literals such as zero need no wrapper.
- Internal type names describe their responsibility without library prefixes; the module provides their namespace. Public and explicit Objective-C names remain deliberate API contracts.
- Default to private or internal. Public APIs need documentation, deliberate defaults and clear ownership.
- New customization uses composition, TMProgressHudProgressReporting or an explicit main-actor progress function. New facade methods are not subclass hooks; preserve the existing open surface only for compatibility.

Keep related source types in responsibility folders (API, Indicators, Layout, Presentation, Progress, Views and Support), mirrored by Xcode groups. Tests follow those responsibilities, with Integration for cross-feature scenarios. Folder changes do not create new modules.

The UIKit facade exposes views and configuration. Separate owners handle layout constraints, presentation phases, scheduled actions and Progress observation. Review each boundary for clear ownership and a concrete reason to exist.

`Indicator` stores a ready view and its update operations. `IndicatorFactory` constructs known indicators with typed operations. `IndicatorConstruction` selects a reusable typed view and preserves its progress contract; `ClientIndicatorAdapter` resolves the independent capabilities of arbitrary client views. `IndicatorColoring` owns appearance resolution; it does not select content or decide reuse. Reuse policy is explicit at facade call sites; reusing a client view preserves its resolved progress operation.

`LayoutCoordinator` coordinates one installation and its visibility observations. The installation owns its invisible spacing views and preserves bezel placement while replacing only the content layout. Construction prepares constraints; explicit activation installs them. Constraint groups own their activation and updates; client constraints stay outside those groups. Visibility observation reuse includes both content identity and its container.

## Safety

Use Swift 6 isolation; UI state and callbacks belong to the main actor. Scheduled actions and observers need explicit owners and cancellation. Preserve the documented timing and callback contracts unless an intentional change is described and covered by regression tests.

No force unwraps, forced casts, force try or hidden concurrency escapes. Handle meaningful failures explicitly. Do not silence compiler warnings or add global mutable state. Discuss any necessary exception in the pull request with a specific safety argument.

## Formatting and review

`swift-format` from Xcode owns formatting and documentation checks: four spaces and a 120-column target. SwiftLint checks production safety and structural metrics. Its version is pinned in `.swiftlint-version`; `.swiftlint.yml` explicitly selects rules without overlapping cosmetic formatting rules. `Scripts/check.sh` runs both tools.

SwiftLint enforces production limits of 350 file lines, 40 function-body lines and complexity 8, using its standard metric definitions. Function-body counts exclude blank and comment lines. Type size (200 nonblank lines), test-file size (500 lines) and test-function size (80 lines) remain manual review triggers. Review a type together with all its extensions: splitting files does not reset its size or responsibility. SwiftLint measures declarations separately and does not enforce this aggregate review. Justify retained large types, and prefer cohesive responsibilities over arbitrary wrappers. Explain necessary deviations rather than splitting cohesive code to satisfy a number. The two regex rules in `.swiftlint.yml` reject runtime traps and concurrency escapes while ignoring comments and strings; there is no separate custom linter.

Tests should assert observable outcomes, including boundary values and repeated operations. Require 100% executable production line coverage with no blanket exclusions. Any proposed exception must identify the exact line, reason and source hash in `Scripts/coverage-exceptions.json`; there are currently none. Compiler-unmapped declarations are separately recorded in `Scripts/coverage-unmapped.json`.
