# QSetup coverage

## Supported capabilities

| Capability | Legacy1-2 | Legacy3-6 | Legacy7-11 | Modern12 |
| --- | --- | --- | --- | --- |
| Structural detection | Yes | Yes | Yes | Yes |
| Metadata and directive parsing | Yes | Yes | Yes | Yes |
| Embedded payload catalog and extraction | Yes | Yes | Yes | Yes |
| Split media | Not verified | Not verified | Not verified | Yes |
| Spanned concatenation | Supported with explicit parts | Supported with explicit parts | Supported with explicit parts | Supported with explicit parts |
| External non-SFX payloads | Supported with explicit companion | Supported with explicit companion | Supported with explicit companion | Supported with explicit companion |
| Built-in ARP projection | Yes when literal | Yes when literal | Yes when literal | Yes when literal |
| Custom ARP and registry writes | where operation grammar matches | where operation grammar matches | Yes | Yes |
| Shortcuts and associations | compact routes | compact and extended routes | extended routes | extended routes |
| Execution Engine | four-command layout | four-command layout | six-command layout | six-command layout |
| Silent policy | documented switch plus dialog gate | same | same | same |
| Blank-name uninstaller fallback | verified | verified | verified only through 7 | verified |
| Payload architecture and dependencies | selective analysis | selective analysis | selective analysis | selective analysis |

"Yes" means the route is implemented and represented by stable media. Runtime-dependent conditions and child-process effects remain conditional evidence.

## Persistent real fixtures

| Fixture | Route | Regression purpose |
| --- | --- | --- |
| QSetup 1.0.0.1 | `Legacy1-2` | direct records, compact footer, comma file lists, four-command actions, compiled `UnInstall_24376.exe` |
| QSetup 4.0.0.4 | `Legacy3-6` | double-pipe preamble and environment operation |
| QSetup 5.0.0.0 | `Legacy3-6` | late four-command action layout and compiled `UnInstall_17836.exe` |
| QSetup 6.0.0.0 | `Legacy3-6` | final double-pipe container with the distinct 67-field transitional action layout and compiled `UnInstall_17836.exe` |
| QSetup 8.1.0.2 | `Legacy7-11` | versioned preamble, six-command actions, legacy footer, undeclared certificate trailer, explicit `un_qstp.exe` |
| QSetup 9.1.0.6 | `Legacy7-11` | confirms the route beyond 8.1 and explicit `un_qstp.exe` |
| QSetup 10.0.2.1 | `Legacy7-11` | confirms legacy footer through 10 and explicit `uninstall_qstp.exe` |
| QSetup 11.0.0.0 | `Legacy7-11` | confirms the final observed legacy-footer generation and explicit `uninstall_qstp.exe` |
| QSetup 12.0.0.5 | `Modern12` | marker footer, current directives, associations, and more than 100 mapped payloads |
| AGTEK Trackwork 2.25.5.6 | `Modern12` | signed 241-record production package with nested VC runtime and more than 10 actions |

Additional archived builder media cover QSetup 2.0, 3.0, 3.5, 7.0, and 7.5. The QSetup 6.0 fixture is the August 2004 Tucows distribution preserved by Internet Archive. Controlled QSetup 12 media cover split kernel and companion authentication, raw external payloads, spanned concatenation, generated uninstaller naming, registry view, command quoting, and zero setup/uninstall exit codes.

## Known gaps

| Gap | Current handling | Evidence needed to close it |
| --- | --- | --- |
| Blank-name uninstaller in QSetup 8 through 11 | leave `UninstallString` unresolved after explicit and shortcut routes fail | one controlled period-Composer project per distinct runtime boundary |
| Separately branded tiny or tiny-verbose grammar | report only bounded `NestedSfxWrapper` structure | builder documentation or media proving another physical grammar |
| Host-dependent Execution Engine predicates | retain condition and runtime-state category | scenario-specific VM evidence |
| External DLL effects | retain call evidence | static inspection of the exact DLL or VM comparison |
| Downloaded content | retain URL and action evidence without fetching | higher-level source workflow and installed-state validation |
| Trailing shortcut flags | preserve complete values as `ObservedFlags` | one-option builder diffs and installed shortcut comparison |
| Copy and destination flag bits | preserve numeric values | controlled projects isolating each bit |

## False-positive controls

Detection rejects marker-only PE files, unrelated zlib overlays, malformed record headers, Setup.txt-like text without the complete container, mismatched counts, invalid footers, and invalid certificate tails. Future negative fixtures should include ordinary signed PE files with zlib resources and non-QSetup setup engines using `SET_` strings.

## Validation expectations

A framing change needs malformed synthetic coverage and at least one distinct archived release. An operation grammar change needs a controlled one-operation project or a production record whose field meaning can be corroborated. ProductCode, scope, silent behavior, generated uninstall naming, and nested ownership require VM comparison when static evidence is conditional.
