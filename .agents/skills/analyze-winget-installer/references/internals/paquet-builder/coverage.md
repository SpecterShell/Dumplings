# Paquet Builder parser coverage

## Persistent fixture matrix

| Cached generation | Structural result | Metadata and extraction coverage | Remaining limitation |
| --- | --- | --- | --- |
| 2.6 incomplete capture | Classic route and GPacker CRC verified | Route classification | Following ZIP is truncated, so package effects are unavailable |
| 2.6 complete | Classic controller, GAF, installed files, shortcuts, registry, associations, and executions | Machine scope and `pbp`/`pbr` associations | No visible uninstall key and no literal absolute `{app}` root |
| 2.7 non-MSI | ISFX, `@GDG`, named resources, GINFOS, and cabinet files | Child `setup.exe` execution | Child ARP identity and scope require nested analysis or VM evidence |
| 2.7 MSI | ISFX, configuration, cabinet, GINFOS, MSI ProductCode and UpgradeCode | Exact nested MSI and cabinet extraction | MSI scope is not explicit in the fixture |
| 2.8 MSI | AP32, named resources, GINFOS, 7z payload, MSI ProductCode and UpgradeCode | Exact nested MSI ownership | Wrapper scope and final destination are dynamic |
| 2.9.1 | Outer and inner GP/LZMA, named resources, GINFOS, 7z payload | Script-selected `Setup1.msi`, ProductCode, UpgradeCode, and ARP tuple | Scope and final destination remain dynamic |
| 2.9.5 and 2.9.6 | Full GP/LZMA program and payload | Machine scope, `PaquetBuilderSetup89`, exact ARP tuple, install path, icon, uninstall string, registry writes, shortcuts, operations, and three extensions | `AUTOSC` internals remain unsimulated; explicit association writes are already parsed |
| 3.0 and 3.2 | Split archives, UPX 13/LZMA launcher image, and runtime catalogs | Exact native assignments, `GDGSoftPB300` ARP identity, machine scope, `%ProgramFiles%\Paquet Builder 3`, payload/runtime extraction, and silent-state evidence | Arbitrary native branches remain outside the scanner |
| 3.6 | Split archives and native evidence | ProductCode, machine scope, and default location | Arbitrary native branches remain outside the scanner |
| 20.1 and 21.0 | Split archives and native evidence | ProductCode, machine scope, default location, runtime catalog | Strict version-resource parsing uses the Windows fallback on these historical layouts |
| Current | Split archives and native evidence | ProductCode, payload/runtime catalogs, silent evidence, user and machine alternatives | Scope and default location are conditional by design |

Two exact 1 MiB archived responses fail structural detection because they are incomplete captures. They are not parser regressions.

## Tested integrity paths

Focused tests cover archive-role classification independent of physical order, zero-length archive entries, incomplete Classic media, complete Classic controller/GAF extraction, Classic CRC corruption, Cabinet2 MSI and non-MSI payloads, AP32 CRC/resource decoding, all three observed 2.9 GP configurations, script-selected MSI ownership, literal ARP reconstruction, file associations, modern uninstall identity, integrity-checked UPX/LZMA reconstruction, exact native-assignment parity with independently unpacked 3.0 and 3.2 launchers, and packed-image checksum corruption.

## Remaining useful work

The Classic absolute application root and 2.7 non-MSI child identity are not stored in the decoded parent structures and should be resolved through VM or nested-installer evidence rather than guessed. Native branches whose variable values come from dialogs, registry reads, or external functions remain intentionally unresolved.

Potential future fixtures include a hidden ARP row, explicit user-scope GINFOS package, conditional multiple uninstall keys, a protocol registration, multiple MSI payloads with one `PBExecMSI` target, and a modern package whose native code computes its uninstall key. These are fixture needs, not reasons to weaken current validation.
