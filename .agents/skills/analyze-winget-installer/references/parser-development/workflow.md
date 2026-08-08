# Parser development workflow

## Boundaries

Keep reusable binary, compression, archive, PE, and safe-path mechanics in shared infrastructure. Keep installer semantics in the focused parser. PackageModule can contain Apache-2.0 or MIT-compatible code; GPL implementations remain behind the InstallerParsers JSON process bridge.

Read [Binary notation](binary-notation.md), [parser contracts](contracts.md), and [performance](performance.md) before changing a parser.

## Loading

Load infrastructure before format modules. Guard managed source compilation so repeated imports and parallel runspaces do not define the same type twice. Mirrored common sources in the two parser submodules must remain byte-identical.

## External tools

Parser modules, tests, bridges, and CI must not depend on `7z.exe`, NanaZip, `isx.exe`, vendor builders, Python extractors, or other executable parsers. Agents may use such tools separately to research and cross-check a format, but their output is supporting evidence rather than the implementation or sole regression oracle.

## Adding a parser

1. Capture stable fixtures and source-backed format references.
2. Define strict content-based detection with false-positive rejection.
3. Parse one opened installer through bounded ranges and preserve stream ownership.
4. Return the shared result contract plus family-specific evidence.
5. Add a focused family workflow and internals page.
6. Add generated malformed fixtures and at least three meaningfully different real layouts when format behavior varies.
7. Add bridge tests when a GPL CLI action or result contract changes.
8. Run targeted Pester suites, ScriptAnalyzer, parity checks, and `git diff --check`.

Extractors resolve paths before managed calls, extract all files when `-Name` is omitted, and expose a collision policy. Interactive calls prompt only after a collision is found; parser-to-parser calls select a noninteractive policy explicitly.

## Documentation structure

Write family workflow headings in sentence case and keep this core order:

1. `When to use`
2. `Detection`
3. `Static analysis`
4. `Manifest shape`
5. `WinGet defaults and overrides`
6. `Apps & Features`
7. `Scope and architecture`
8. `VM validation`
9. `Known examples`

Add `Wrapper behavior`, `Update feeds`, `Dependencies`, or `Silent behavior` only for family-specific guidance. Put parser commands under `Static analysis` and link to the matching internals overview near the first command. Keep shared manifest, wrapper, evidence, and VM procedures in their canonical workflows.

Use this order for parser-internals overviews:

1. `Supported formats and variants`
2. `Binary structure`
3. `Detection invariants`
4. `Metadata projection`
5. `Bounds and malformed input`
6. `Performance considerations`
7. `Known gaps`
8. `Implementation mapping`
9. `Representative fixtures`
10. `Source references`

Insert `Compression and transforms` or `Payload selection and nested execution` after `Binary structure` when needed. Variant internals pages use the smaller sequence `Binary structure`, `Parsing behavior`, `Metadata projection`, and `Limits and gaps`. Keep upstream sources in the overview's final section rather than repeating them across variant pages.

Split a workflow near 250 lines or 2,500 words and an internals overview materially above 300 lines. The main workflow must still expose the complete core outline and route to focused secondary pages. Use descriptive headings in those pages rather than continuing a numbered sequence across files.
