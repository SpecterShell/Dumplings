# CreateInstall coverage

Coverage is structural. A supported capability has a bounded implementation and distinct evidence; it does not imply that every Gentee expression or external side effect is statically decidable.

## Capability matrix

| Capability | GE4 + GEA1 | GE4 + GEA2 | GE4 without GEA |
| --- | --- | --- | --- |
| Structural installer detection | yes | yes | yes |
| Project identity and variables | yes | yes | yes |
| Stored GE program | supported route | supported route | supported route |
| LZGE-packed GE program | yes | yes | yes |
| Physical payload catalog | yes | yes | absent by design |
| Store extraction | yes | yes | not applicable |
| LZGE extraction | yes | yes | not applicable |
| Gentee PPMd-I extraction and solid continuation | yes where used | yes | not applicable |
| Spanned logical data | synthetic verified | route shared | not applicable |
| Installed-file projection | `Direct5` and `Extended6` | `Extended6` | empty unless files are external or generated |
| Built-in Add/Remove profiles | `Legacy3`, `Scoped4`, `Policy4`, `Extended5` | `Extended5` | supported when linked |
| Deterministic custom ARP writes | yes | yes | yes |
| Literal protocols and extensions | yes | yes | yes |
| Shortcuts, runs, registry, environment, prerequisites, services, registrations, tasks, copy, download, archive, and INI evidence | source-backed routes | source-backed routes | source-backed routes when linked |
| Payload architecture and PE dependencies | selective extraction | selective extraction | unavailable without local payload files |
| Encrypted payload extraction | no | no | not applicable |
| Arbitrary `@function` execution | no; bounded evidence | no; bounded evidence | no; bounded evidence |

## Historical fixtures

| Fixture group | Route purpose |
| --- | --- |
| official 5.9.0 builder | oldest verified GE4/GEA1 media, `Direct5`, `Legacy3`, empty `silentpar` |
| official 5.19.1 through 6.3.3 builders | `Extended6`, `Legacy3`, GEA1, `-silent` corpus boundary |
| official 6.4.0 through 7.0.19 builders | `Scoped4` current-user argument and `InstallLocation` |
| official 7.0.26 through 7.1.3 builders | `Policy4` with `NoModify` and `NoRepair` |
| official 7.1.7 through 7.4.0 builders | `Extended5` estimated-size route on GEA1 |
| official 8.0.1 and 8.11.2 builders | GEA2 64-bit size fields and current operation set |
| `CrossPlusA.Balabolka` | production PPMd-I, solid state, conditional groups, Visual C++ check, extensions, and exact ARP identity |
| controlled Run MSI setup | source-backed `runmsiex` action, UI, restart, log, wait, and nested-path projection |
| controlled no-payload setup | valid GE4 installer with no GEA and no marker-dependent analyzer route |
| controlled Extended5 installed-state sample | exact HKLM 32-bit ARP value set, quoted uninstaller, install log, and generated no-GEA uninstaller |
| controlled environment-operation sample | exact GE4 `globappend` and `globdel` literal sequences and caller argument projection |
| synthetic spanned archive | companion name, identity, logical range translation, stored extraction, and missing-volume diagnostics |
| corrupted GE program and archive cases | header CRC, truncation, count, range, volume identity, checksum, and extraction-limit rejection |
| `ci2000.exe`, `setupgen.exe`, and `sgpro.exe` | negative predecessor-family controls |

The external fixture cache contains additional official point releases from 6.1.0, 6.1.1, 6.1.2, 6.2.1, 6.3.1, 7.0.14, 7.2.0, 7.2.1, 7.2.2, and 7.3.2. They are useful for transition research even when the table-driven committed regression set uses representative boundaries.

## VM-backed evidence

The controlled Extended5 project was installed and uninstalled in the VM. Its visible ARP key, registry view, display values, install location, icon, uninstall command, policy values, and generated installation log matched static reconstruction. A trial setup invoked with `-s` remained interactive. The focused workflow still requires artifact-specific VM validation when a package's runtime conditions or external payloads affect submission fields.

## Known gaps

| Gap | Current handling | Evidence needed |
| --- | --- | --- |
| pre-CreateInstall Gentee Installer products | rejected as a separate family | independent format and runtime model |
| builder releases before 5.9.0 or a structurally new release after 8.11.2 | reject unless an existing route validates completely | distinct media and source- or builder-backed route |
| arbitrary `@function` predicates | bounded command, literal, call, variable, and context evidence | source-grounded evaluator for a safe subset or VM result for the exact operation |
| unknown `globappend`/`globdel` variant | `AppendOrRemove` diagnostic | controlled compiler output establishing a new exact literal sequence |
| INI formatting and line insertion, text insert/delete, and remaining generated-file operations | retain source calls or unresolved behavior | route-specific source grammar and controlled output |
| indirect calls outside literal/list forms | preserve unresolved expression | bounded call-target proof |
| external linked DLL side effects | report import and execution evidence | static DLL analysis or VM comparison |
| password-protected GEA entries | catalog only, extraction disabled | independently licensed decryption implementation plus fixtures |
| recursively installed content from nested 7z, cabinet, or ZIP operations | report operation only | safe nested selection and ownership rules for each exact route |
| downloaded payload metadata | report URL and destination, never fetch | higher-level source workflow and target artifact analysis |
| generated-uninstaller quiet behavior | leave `QuietUninstallString` null | source-backed command-line route and cross-generation VM validation |
| family-wide process return codes | no override | controlled success, cancellation, prerequisite, and child-failure matrix |

## Validation expectations

Detection changes need marker-only, ordinary `.gentee`-named, predecessor, no-payload, and supported real-media tests. GE changes need valid and corrupt header CRCs plus exact object-table termination. GEA changes need full-file CRC validation across Store, LZGE, PPMd, solid continuation, and spanned ranges. ARP, switch, scope, and child-installability changes require installed-state evidence when they affect a manifest.
