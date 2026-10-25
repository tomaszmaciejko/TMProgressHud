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

`swift format` owns formatting: four spaces and a 120-column target. `Scripts/check.sh` runs formatting, API documentation and structural checks.

Production review limits are 350 nonblank lines per file, 200 per type, 40 per function and complexity 8. Tests allow 500 lines per file and 80 per function. Type size is reviewed manually; the other limits are checked automatically. Explain necessary deviations rather than splitting cohesive code to satisfy a number.

Tests should assert observable outcomes, including boundary values and repeated operations. Require 100% executable production line coverage with no blanket exclusions. Any proposed exception must identify the exact line, reason and source hash in `Scripts/coverage-exceptions.json`; there are currently none. Compiler-unmapped declarations are separately recorded in `Scripts/coverage-unmapped.json`.
