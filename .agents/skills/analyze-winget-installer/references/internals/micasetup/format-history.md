# MicaSetup format history

MicaSetup retained the managed PE, generated CIL, WPF `.g.resources`, and nested `publish.7z` architecture from v1.0.0 through v2.5.6. Most changes are additions to configuration and runtime behavior rather than new container formats.

| First release | Change | Parser treatment |
| --- | --- | --- |
| 1.0.0 | `MicaSetup.Core.Pack` with `UsePack`; Pack implementation may be supplied through Costura references | `Pack`, v1 source-compatible route |
| 1.1.0 | `MicaSetup.Core.Option` replaces Pack while the host still uses `UsePack`; autorun property is misspelled `IsCrateAsAutoRun` | `OptionLegacy`; normalize the typo and accept the transitional host |
| 1.3.0 | Option moves toward the later v1 host shape | `OptionLegacy` |
| 2.0.0 | Source and UI reorganization without a new physical container | `OptionLegacy`; release major alone does not select a parser route |
| 2.0.1 | custom overlay cleanup handler | report handler presence; do not execute it |
| 2.3.1 | PATH modification option | project a PATH system effect |
| 2.3.3 | `IsUninstLower` | first `OptionModern` compatibility boundary |
| 2.3.7 | local Programs and roaming AppData path preferences | include both in manifest-safe location resolution |
| 2.5.1 | `CloseApplications` becomes an array | evaluate official object initializers with source defaults |
| 2.5.5 | `OverlayInstallRemovePatterns` becomes a string array | decode compiler-emitted literal arrays |
| after 2.5.6 on the untagged v2 branch | `SupportLanguages` and opt-in language/license packaging | prefer a resolved option, otherwise inspect packaged language dictionaries |

`FormatCompatibility` reports the verified source interval for a configuration schema. It does not prove the exact runtime commit in a distributed installer. A fork can copy an old Option type into a new build or add fields without changing the container.

## Compatibility rules

Route selection requires structural configuration-host and resource evidence. Pack versus Option is determined from CLR type/member references and generated setter calls. Legacy versus modern Option is determined from schema members used by the artifact, including `IsUninstLower` and later path options. Assembly version is application data and cannot override these findings.

An unknown additive option does not invalidate the complete parser result. The parser retains the unknown assignment as evidence and reports unresolved behavior when it can affect installation. A changed `.resources` runtime version, unsupported resource type, missing `publish.7z`, or incompatible generated host is a structural failure rather than a future-version guess.
