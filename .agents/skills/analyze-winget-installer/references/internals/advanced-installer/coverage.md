# Coverage and remaining work

## Implementation parity

| Area | Status | Evidence or remaining work |
| --- | --- | --- |
| Physical footer | Implemented | Source-grounded 74-byte `footer-v1`, self-pointer, per-build RFC 4122 version-4 bootstrapper UUID, signed tails, and bounds. |
| Unicode catalog | Implemented | Exact 20-byte v0 records on a controlled 6.4 build and exact 24-byte v1 records on controlled 8.6 plus TI-Nspire, TeraCopy, FxSound, Devolutions, and BenchMate media. |
| ANSI catalog | Partially validated | Exact 20-byte records and Windows-1252 names are validated against controlled Advanced Installer 6.3 media. The catalog can route structurally compatible 1.4–6.2 media, but those release boundaries still require official generated EXE fixtures. |
| Configuration | Implemented | BOM and BOM-less Unicode/ANSI detection with literal INI projection. |
| Direct embedded MSI | Implemented | TI-Nspire and Dragonframe fixtures. |
| Nested 7z/LZMA main package | Implemented | TeraCopy, Devolutions, and BenchMate fixtures. |
| Web `MainAppURL` | Implemented | A controlled 8.6 web build validates URL precedence, external role-6 and role-7 siblings, and `Download` selection without fetching the package. |
| External MSI/CAB resources | Implemented | The footer count, ANSI/Unicode sibling tables, role projection, safe sibling resolution, missing-media warnings, extraction, and nested MSI selection are validated against controlled 6.3 and 6.4 builds. |
| Classic x86/x64 selection | Implemented | Cjwdev, TeraCopy, and FxSound mixed package evidence. |
| ARM64 fixed path | Implemented | FxSound ARM64 fixture. |
| MSI/MSIX platform wrapper | Implemented | A controlled 23.9 sparse-package build validates MSI selector `(1, 0)`, MSIX selector `(1, 18)`, `AppxVersion`, `AppxPkId`, embedded extraction, and operating-system selection evidence. Direct MSIX/AppX still stays with the package parser. |
| AES archive | Implemented as detection and rejection | A controlled Advanced Installer 8.6 build validates SharpCompress AES-256 entry evidence, deterministic rejection without a password, and release of the temporary archive handle. Decryption and password recovery remain out of scope. |
| Unknown transform | Implemented as opaque | Extraction fails with a structured error rather than copying undecoded bytes. |
| Exact EXE builder version | Conditional | Reported only when explicit configuration preserves it. |
| Exact MSI builder version | Implemented | `SummaryInformation.CreatingApp`, including official 6.4, 8.6, and 23.9 builder MSIs and TI-Nspire 10.3. |
| Project schema | Conditional | Reported only from an explicit compiled key; no inference from release number. |
| Commercial edition | Intentionally unavailable | Generated media normally does not preserve the build license. |
| Prerequisite execution semantics | Implemented static projection | Controlled 8.6 file, compressed, force-install, and URL prerequisites validate catalog payloads plus `AI_PreRequisite` and `AI_AppSearchEx` metadata. `MissingCondition` is parsed with MSI grammar, search rows are joined through exact referenced symbols, and explicit caller properties produce `True`, `False`, or `Unknown`. Child elevation and actual silent behavior still require child analysis or VM validation. |

## Fixture policy

Historical official builders and generated media belong in the persistent sibling `Dumplings-TestFixtures` cache. Builders and generated installers run only in the checkpointed Hyper-V VM. CI should skip unavailable historical downloads rather than use a user's Downloads, Temp, Sandbox, or submission-installer directory.

Official 6.3, 6.4, 8.6, and 23.9 builders produced controlled EXE media inside the Hyper-V VM. Version 6.3 establishes the ANSI v0 catalog and external sibling table, version 6.4 establishes the Unicode v0 catalog and sibling table, version 8.6 establishes the Unicode v1 catalog with transform words, web media, prerequisites, and AES-protected payloads, and version 23.9 establishes the mixed MSI/MSIX selector route. Their nested MSI `SummaryInformation.CreatingApp` values independently confirm the builder versions. The generated installers and sibling resources are cached under `Dumplings-TestFixtures/InstallerParsers/AdvancedInstaller/Generated` and are never executed on the host.

Official archived `advinst.msi` captures identify Advanced Installer 0.1, 0.4, and 1.3 builder packages. They establish that early Advanced Installer distribution was MSI-based, but they do not validate the EXE bootstrapper introduced afterward. A third-party 6.2 archive is retained only as provenance-labeled research material because its unsigned repack cannot serve as an authoritative format fixture and is not executed.

## Behaviorally distinct real fixtures

| Fixture | Route |
| --- | --- |
| TI-Nspire Computer Link | Direct MSI, exact Advanced Installer 10.3 MSI authoring evidence. |
| TeraCopy 3.9 | Nested archive and classic x86/x64 suffix selection. |
| Cjwdev AD Account Reset Tool | Two architecture-selected MSI paths. |
| FxSound | Mixed x86/x64 package plus separate fixed ARM64 media. |
| Devolutions Server Console | Footer before a large Authenticode tail and nested archive. |
| BenchMate | More than 2 GiB, nested package extraction, and performance watchdog. |
| Controlled 23.9 sparse-package wrapper | Operating-system selection between an embedded MSI and selector `(1, 18)` MSIX, including package identity and minimum-Windows-version configuration. |

## Highest-value additions

The highest-value missing fixtures are official generated EXEs from 1.4, 1.8, 3.6, 4.4, and 6.1. They should either confirm the ANSI v0 route or establish earlier footer, catalog, compression, or selection profiles. Current releases after 23.9 should be added only when they change footer framing, catalog records, transforms, or runtime selection.
