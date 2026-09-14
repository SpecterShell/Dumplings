# Zero Install coverage

## Supported capabilities

| Capability | Current support |
| --- | --- |
| managed bootstrapper detection | historical CLR identity and all catalogued configuration resources |
| configuration precedence | embedded fixed lines, historical appSettings, embedded INI, adjacent basename INI |
| runtime feature gates | version-backed silent, scope, store, integration, ARP, and option boundaries |
| feed metadata | localized package text, implementations, package implementations, groups, entry points, commands, dependencies, bindings, restrictions, and references |
| version conditions | exact, exclusion, bounded/open ranges, unions, and inherited conditions |
| capabilities | Windows URL protocols and file types with deterministic integration selection |
| bootstrap content | embedded and explicit top-level content-directory records |
| offline implementation | archive, file, rename, remove, copy-from, normalized manifest generation, and digest verification |
| ARP | versioned display name, publisher, modify path, scope, commands, and escaped URI identity |
| solver, trust, and network | deliberately not implemented |

## Persistent fixtures

The suite covers the authentic source-built 2.11.5 bootstrapper, official generic releases 2.16.0, 2.21.0, 2.22.0, 2.23.0, 2.23.1, 2.23.3, 2.24.0, 2.24.6, 2.24.8, 2.25.3, 2.25.12, and 2.29.0, plus the current `DeepL.DeepL` application bootstrapper. The stock `0install.exe` and `0install-win.exe` runtime executables are not application bootstrapper fixtures and must not be accepted merely because they share product branding.

Synthetic feeds cover inheritance, localized metadata, `xml:base`, runtime-version conditions, entry points, package implementations, dependencies, commands, runners, capabilities, recipes, unknown steps, manifest digests, malformed values, archive extraction, copy-from, and verify-before-publish behavior.

## Known boundaries

| Boundary | Current handling | Evidence needed to extend it |
| --- | --- | --- |
| solver selection | expose all normalized inputs and limited runtime applicability | independently implement complete policy only if a concrete authoring workflow requires it |
| feed signatures and trust | preserve key and feed evidence | trusted runtime or independently reviewed cryptographic implementation |
| distribution packages | expose package implementation records | provider-specific installed-state resolver |
| dynamic feed imports | retain references and applicability | caller supplies resolved signed documents |
| network retrieval | return URIs and expected sizes | caller acquires trusted artifacts outside parser |
| runtime absolute paths | return argument arrays and relative executable identity | deployed runtime state |
| archive links | reject before publication | link-aware provider with manifest-preserving Windows semantics |
| unsupported archive types | explicit unsupported operation | source-backed managed provider plus distinct fixture |
| first-run target effects | outside bootstrapper projection | after-first-run VM snapshot |
| legacy `sha1=` implementation manifest | verify with source-backed directory timestamps and interleaved path ordering | official historical implementation archive or malformed timestamp evidence |

The solver, trust store, and network client are independent systems rather than missing bootstrapper fields. Adding them to the parser would increase risk without improving ordinary WinGet manifest authoring.
