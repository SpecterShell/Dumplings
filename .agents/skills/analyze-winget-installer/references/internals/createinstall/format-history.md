# CreateInstall format history

## Independent route axes

CreateInstall did not evolve as one monolithic file version. Parser dispatch is compositional: the GE program route, GEA width, install-group call shape, Add/Remove routine, and optional operation modules are classified independently. A product version is regression evidence and must not override validated structure.

| Axis | Verified routes | Selection evidence |
| --- | --- | --- |
| Compiled program | `GE4Launcher` | launcher header, GE header version, complete object table, and referenced `MAINVAR` |
| Payload archive | absent, `GEA1`, `GEA2` | validated GEA header and size-field width |
| Install groups | `Direct5`, `Extended6` | target routine parameter count and source-backed list shape |
| Add/Remove | absent, `Legacy3`, `Scoped4`, `Policy4`, `Extended5` | registry-path routine fingerprint, value-name set, argument count, and direct calls |
| Operations | catalog entries such as `RunMsi11`, `RegistryList5`, and `DownloadList8` | parameter count, literal fingerprint, imports, call graph, and list schema |

## Observed chronology

| Builder evidence | Program | Archive | Install group | Add/Remove |
| --- | --- | --- | --- | --- |
| 5.9.0 | GE 4 | GEA1 | `Direct5` | `Legacy3` |
| 5.19.1 through 6.3.3 | GE 4 | GEA1 | `Extended6` | `Legacy3` |
| 6.4.0 through 7.0.19 | GE 4 | GEA1 | `Extended6` | `Scoped4` |
| 7.0.26 through 7.1.3 | GE 4 | GEA1 | `Extended6` | `Policy4` |
| 7.1.7 through 7.4.0 | GE 4 | GEA1 | `Extended6` | `Extended5` |
| 8.0.1 through 8.11.2 | GE 4 | GEA2 | `Extended6` | `Extended5` |

The available artifacts bound transitions rather than proving the first release that shipped each format. For example, the archive width changed after 7.4.0 and no later than 8.0.1. A future artifact is accepted only when one existing structural route validates completely or a new catalog descriptor is added.

## Silent behavior history

The compiled `MAINVAR.silentpar` value is authoritative. The official 5.9.0 builder installer has an empty value and is projected as interactive-only. Every cached official builder installer from 5.19.1 through 8.11.2 has `-silent`. This is an observed corpus boundary, not a hard-coded version rule: a package author can configure a different value or leave it empty in any supported generation.

The unsupported `-s` form was tested against controlled current media and displayed the normal wizard. Never normalize a compiled switch to a familiar spelling.

## Operation availability

The linked module set changes with project features and builder generation. Copy, download, cabinet, INI set/format, service, directory, delete, rename, attribute, and replace support appears in the cached 5.9.0 media. Scheduled tasks, 7z, and ZIP appear by 5.19.1. INI line insertion appears by 6.0.0, text insertion and deletion by 6.2.1, and INI-key deletion by 6.4.0.

These ranges describe linked capability in the sampled builders. The parser reports an operation only when the compiled program contains the matching call route; a routine present in dead code is not proof that the project schedules it.

## Predecessor boundary

The Gentee Installer artifacts named `ci2000.exe`, `setupgen.exe`, and `sgpro.exe` are negative fixtures. Shared publisher strings, Gentee code, or an installer purpose do not bridge the structural gap. Supporting them requires a separate family and format model rather than weakening CreateInstall detection.
