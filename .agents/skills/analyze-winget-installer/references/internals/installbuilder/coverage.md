# InstallBuilder coverage

## Supported capabilities

The parser currently provides these static capabilities for structurally validated Windows media:

- Strict PE plus project/container detection for `LegacyMetakit`, `CookFS2`, and metadata-only `ProjectRecord` routes.
- Exact Metakit VFS parsing for `dirs[name:S,parent:I,files[name:S,size:I,date:I,contents:B]]`, including adaptive descriptors, integer columns, inline and memo byte columns, parent graphs, and multiple embedded VFS databases.
- Legacy payload extraction from stored and zlib `contents:B` records below the `origindist` package directory.
- CookFS2 footer, page table, file index, metadata, 64-bit modification-time, block, and split-file parsing.
- CookFS stored, Deflate, BZip2, and validated unencrypted LZMA decompression.
- MD5 and CookFS CRC32 expanded-page verification.
- Recursive project identity substitution and manifest-safe known-folder projection.
- Default component, folder, platform, and condition selection with explicit conditional and excluded payload lists.
- Installation-mode allowlists, legacy unattended mode, current unattended UI modes, custom install-location option names, and debug logging switches.
- Requested execution level, root-install requirement, package scope evidence, shortcut scope, registry view, launcher architecture, and optional installed payload architecture analysis.
- Built-in uninstaller and Windows ARP reconstruction, ordered custom registry sets and deletes, hidden and uncertain entries, and post-uninstaller-creation override behavior.
- Native and registry-derived protocols and file extensions, including deterministic association removal.
- Phase-aware shortcuts, environment and PATH changes, services, scheduled tasks, fonts, shared-DLL references, Windows ACL changes, and child execution records.
- Structured Java and .NET Framework runtime requirements.
- Exact unresolved condition, expression, and script evidence with referenced variable classification and sensitive-value redaction.
- Bounded extraction of one, wildcard-selected, or all logical payload files with safe paths and collision handling.
- Scenario-neutral structured diagnostics and WinGet projection through the analyzer.

## Persistent real fixtures

Durable downloads belong under `Dumplings-TestFixtures/Installers/InstallBuilder` through the shared fixture catalog. They are not committed to the repository.

| Fixture | SHA256 | Structural distinction | Key assertions |
| --- | --- | --- | --- |
| `installbuilder-3.6.0-windows-installer.exe` | `8A74835E0693945281739841D53D6890F147A8CEF2FEC03714B9D903ECB2F9ED` | Legacy Metakit-only BitRock builder | Project schema 1.2, 317 VFS records, 88 installed payloads, stored and zlib contents |
| `jxplorer-3.3.1.2-windows-installer.exe` | `C1FE14A60BC6AA909EA8C1D5F09EB7426722BDD90634B451C12D1A32D10FF67B` | Third-party CookFS2 with stored and Deflate pages | 189 default payload files, CRC32 evidence, Java requirement |
| `installbuilder-enterprise-8.2.0-windows-installer.exe` | `92CF98DC56AF7631D237CC41A83DB1660D9A66657BD7DCB9DFA29F6205C563F7` | Two valid Metakit VFS databases plus LZMA CookFS2 | Required-entry ownership and byte-exact extraction |
| `installbuilder-9.5.5-windows-installer.exe` | `E7BEA2FAE49D9291346154D631FFA9A197CF2C88394416B351867B385DCE159F` | Later BitRock LZMA route | LZMA framing and project/runtime continuity |
| `installbuilder-23.1.0-windows-installer.exe` | `C4434CFD64491E18A28D893FBD8D3535448FD22DDF869DE7AE61F190CE88891E` | Backstaff rebrand with x86 launcher | Branding separation and unchanged CookFS2 route |
| `installbuilder-26.8.0-windows-x64-installer.exe` | `D731DFF8E6C138C9E8866FD8C2D530CA479B62ABCF93E87360C08654712FBEA7` | Current native x64 Backstaff media | 64-bit view, current metadata, LZMA, full ARP defaults, installed primary executable analysis |

All six fixtures currently produce empty top-level `UnresolvedFields` under normal metadata parsing. Some contain reviewable project logic, but lifecycle-scoped field attribution prevents presentation-only or unrelated expressions from invalidating ProductCode, scope, switches, or payload conclusions.

## Additional research corpus

The research corpus also includes structurally inspected InstallBuilder 3.7.0, recovered 4.5.3, 7.2.5, and 16.1.0 builder media. These artifacts extend release and runtime-template observations without becoming routine test downloads when they do not add a distinct regression path.

| Media | Contribution |
| --- | --- |
| 3.7.0 | Confirms the legacy Metakit route and project vocabulary after 3.6.0 |
| nominal archived 4.2.0, internally recovered as 4.5.3 | Proves archive names can disagree with compiled identity and confirms later Metakit-only media |
| 7.2.5 | Confirms the observed unencrypted custom LZMA handler on CookFS2 |
| 16.1.0 | Confirms later action vocabulary without a container-format change |

Static extraction from recovered builder packages produced 15 distinct Windows runtime templates across the researched generations. Those templates are evidence for packing, branding, architecture, and capability boundaries; production parsing still dispatches from installed package structures.

## Synthetic coverage

Generated Pester fixtures exercise conditions that are difficult or unsafe to obtain from redistributable production installers:

- Large numbers of incidental `0x78` bytes before a valid zlib project record.
- Built-in ARP defaults, hidden custom ARP, HKCU custom ARP, deterministic built-in deletion, custom replacement, and conditional final deletion.
- Recursive identity values and unresolved identity expressions.
- Nested conditions on registry operations, unrelated dynamic registry values, non-installation phases, folder action lists, and ordered deletes.
- Native association creation and removal.
- .NET Framework requirement ranges and the supported condition subset.
- Manifest-safe Windows known-folder variables.
- Persistent environment, PATH, service, scheduled task, font, shared-DLL, and ACL actions with password redaction.
- Exact dynamic logic records and lifecycle-scoped affected fields.
- Interactive-only, unattended-only legacy, and unattended current-mode projections.
- Stored and BZip2 CookFS records, split logical files, component selection, timestamps, MD5, CRC32, corrupt hashes, and unsupported handler records.
- Nested installer candidates and final-page application launches.
- Marker-only rejection and malformed Metakit root rejection.

## Byte-exact extraction evidence

The durable suite compares extracted size and SHA256 for distinct physical routes rather than checking only filenames. Legacy 3.6.0 full extraction verifies 89 outputs including `project.xml`, `demo/docs/license.txt`, `demo/bin/demo.txt`, and `bin/builder.exe`. CookFS coverage includes a Deflate file from JXplorer, an LZMA file from 8.2.0 media, and a current logical destination from 26.8.0.

CookFS page tests separately corrupt integrity bytes and require extraction to fail before an output is accepted. Metakit tests corrupt the commit-root range and require the catalog reader to reject it.

## VM-validated evidence

The current 26.8.0 x64 builder installer has controlled installed-state evidence for:

- Self-elevating machine installation.
- Native 64-bit uninstall registry view.
- ProductCode `InstallBuilder for Windows 26.8.0`.
- Display name, version, publisher, install location, icon, information URL, help link, `NoModify`, and `NoRepair` matching parser output.
- Quoted generated uninstaller command.
- Unattended installation with exit code zero.
- Unattended uninstallation with exit code zero and removal of the ARP key and installation directory.

This matrix validates current built-in defaults. Custom registry actions, dual-scope branches, upgrade projects, nested installers, and host-dependent Tcl still require package-specific VM evidence.

## Known gaps

### Encrypted and custom CookFS handlers

InstallBuilder 8.2 introduced payload encryption. Handler `255` is accepted only when it matches the source-backed unencrypted LZMA form. Password-protected, encrypted, or arbitrary custom compression requires project-specific decoding and remains unsupported. The parser reports the handler and avoids exposing password material.

### Arbitrary Tcl and external code

Tcl expressions, TclPro bytecode, scripts, DLL calls, command output, network data, and child-process side effects are not emulated. Exact source and known variables are returned for review. Runtime-dependent consequences remain diagnostics and VM-validation targets.

### Host-dependent conditions

Filesystem, registry, Windows-version, service, process, and UI-state rules remain unknown without a trusted target-state context. The parser can still use short-circuit results when another branch determines the outcome.

### Runtime-generated ARP values

`EstimatedSize` and `InstallDate` are not statically reconstructed. Upgrade installers can also reuse a prior ProductCode or install directory that is unavailable in the new artifact.

### Unnormalized action families

Every compiled leaf action is retained in `ProjectActions`, but only the documented system-effect families in [metadata model](metadata-model.md) receive typed projections. Less common action types remain source records until their runtime semantics and lifecycle impact are established.

### Historical availability

A true InstallBuilder 2.6.1 artifact and a verified 5.4.15 artifact are unavailable in the current corpus. The archived 2.6.1 URL returns 3.7.0 media, while observed 5.4.15 captures are HTML, replay failures, or later redirects. No format gap is claimed without distinct bytes.

### Exact builder version

Third-party projects can replace PE product versions and share a structural route across many builder releases. The parser reports project schema, structural generation, and available producer evidence but does not invent an exact patch version.

## False-positive controls

The following evidence is insufficient by itself:

- `BitRock`, `VMware InstallBuilder`, `InstallBuilder`, or `Backstaff` strings.
- `--mode unattended`, `unattendedmodeui`, or Tcl/Tk strings.
- A `project.xml` filename without a bounded parseable project.
- An isolated `JL`, `LJ`, `CFS2.200`, or `CFS0002` marker.
- A generic TclKit or CookFS application.
- A PE version resource naming an InstallBuilder-produced application.

Strict detection requires a valid PE and structured project/container ownership. Unsupported but strongly identified media should return a structured incomplete or unsupported diagnostic rather than be routed as a successful parse.

## Validation expectations

A parser change should run the focused InstallBuilder Pester suite, installer analyzer and WinGet suggestion regressions when projection changes, ScriptAnalyzer on the module, clean module import, and `git diff --check`. Any change to shared binary, archive, compression, PE, path, or diagnostic infrastructure also requires the affected cross-family suites and shared-source parity checks.

A new structural route is incomplete until it has a real fixture, a malformed-range negative test, byte-exact extraction evidence, and updated binary documentation. A new semantic projection is incomplete until source or controlled builder evidence establishes meaning and VM evidence confirms runtime behavior when static structure is insufficient.

## Source references

- [InstallBuilder downloads](https://installbuilder.com/download-step-2)
- [InstallBuilder release archive](https://releases.installbuilder.com/installbuilder/)
- [InstallBuilder changelog](https://installbuilder.com/changelog)
- [InstallBuilder user guide](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/)
- [Archived InstallBuilder 3.6.0 media](https://web.archive.org/web/20060419104749id_/http://www.bitrock.com/installbuilder-3.6.0-windows-installer.exe)
- [Archived InstallBuilder 8.2.0 media](https://web.archive.org/web/20120607082324id_/http://installbuilder.bitrock.com/installbuilder-enterprise-8.2.0-windows-installer.exe)
- [Archived InstallBuilder 9.5.5 media](https://web.archive.org/web/20150513id_/http://installbuilder.bitrock.com/installbuilder-9.5.5-windows-installer.exe)
