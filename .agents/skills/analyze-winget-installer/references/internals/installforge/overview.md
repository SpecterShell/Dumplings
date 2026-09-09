# InstallForge internals

This reference describes the InstallForge setup structures consumed by Dumplings. It is intended for format research, parser maintenance, and review of claims derived from compiled media. Use the [InstallForge workflow](../../families/installforge/workflow.md) for package analysis and manifest decisions.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the implementation.

## Release lineage

InstallForge has three payload routes across two configuration generations in the verified corpus. Builder version 1.4 introduced a new native Unicode setup engine, CRC checking, JSON uninstaller configuration, a resource-hosted 7z configuration, and a GZip-compressed TAR payload. Builder version 1.5 changed the builder project format to XML, added a command-line builder, and changed generated payload media to 7z.

| Builder range | Parser generation | Configuration container | Payload container | Verified examples |
| --- | --- | --- | --- | --- |
| 1.2.2 through 1.3.2 | `Legacy` | Microsoft Cabinet in the PE overlay | ZIP after the cabinet | Archived 1.2.2, 1.2.6.2, 1.2.7, 1.2.9.2, and 1.3.2 builders |
| 1.4.x | `Modern` configuration | 7z in `RCDATA/SETUPCONFIGURATION` | ``JGTFUVQ`TUBSU`` header followed by GZip/TAR | Archived 1.4.2 and 1.4.4 builders |
| 1.5 and later | `Modern` | 7z in `RCDATA/SETUPCONFIGURATION` | ``JGTFUVQ`TUBSU`` header followed by 7z | Official 1.5.0, 1.6.0, and 1.6.1 releases |

The transition is selected by physical structure, not PE version strings. A newer builder project file can therefore be discussed separately from the setup engine that consumes the compiled output.

## Evidence model

The parser uses three evidence classes. Container evidence proves that a PE has the expected InstallForge configuration and payload relationship. Compiled configuration evidence provides product settings and operation records. Installed-state evidence proves how the runtime converts those settings into Windows registry values.

The modern ARP mapping was verified with controlled InstallForge 1.6.1 projects and VM snapshots. Legacy VM validation proves two runtime behaviors: the 1.2.2 setup packages an uninstaller but creates no ARP row, while the 1.2.6.2 and 1.3.2 runtimes register `Appname` as the HKLM 32-bit uninstall-key identity. The parser selects these behaviors from the runtime's bounded uninstall-registration code evidence rather than a version-string threshold.

## Layered binary maps

### Legacy 1.2.x through 1.3.x

```text
InstallForge setup executable
+-- PE headers and setup runtime
`-- PE overlay                                        absolute OverlayOffset
    +-- optional runtime-owned prefix                 observed, at most 1 MiB before CAB
    +-- Microsoft Cabinet                             starts with 4D 53 43 46, "MSCF"
    |   +-- SC.dat                                    INI configuration
    |   +-- operation tables                          Registry.dat, Desktop.dat, Startmenu.dat, OS.dat, and optional tables
    |   `-- language, license, and serial data
    +-- optional separator                            observed 0 or 8 bytes; semantics unknown
    `-- ZIP payload                                   bounded from ZIP central directory and EOCD
        `-- installed files                           ordinary relative names
```

The parser scans only the first 1 MiB of the overlay for candidate cabinet signatures. A candidate is accepted only when its declared cabinet length is bounded by the file and the expanded cabinet contains a usable `SC.dat`. Payload selection then considers complete embedded ZIP ranges that begin after the accepted cabinet.

### Transitional 1.4.x

```text
InstallForge setup executable
+-- PE headers and native setup runtime
+-- .rsrc/RCDATA/SETUPCONFIGURATION -> 7z configuration archive
`-- PE overlay
    +-- marker: 4A 47 54 46 55 56 51 60 54 55 42 53 55, "JGTFUVQ`TUBSU"
    +-- observed header field                              8 bytes; semantics unresolved
    `-- GZip stream                                      1F 8B
        `-- POSIX TAR payload                            Base64 UTF-16LE path fields
```

The marker is the bytewise incremented text `IFSETUP_START`. Controlled inspection proves that the GZip stream starts 21 bytes after the overlay start and decompresses to a valid TAR archive. Signed media may append the PE certificate table after the GZip member. The parser bounds the compressed stream at the certificate-table offset, validates GZip and TAR framing, and decodes the TAR catalog without materializing the complete payload.

### Modern 1.5 and later

```text
InstallForge setup executable
+-- PE headers and native setup runtime
+-- .rsrc
|   `-- RCDATA / SETUPCONFIGURATION                   PE resource-relative range
|       `-- 7z configuration archive                  37 7A BC AF 27 1C
|           +-- SC.dat                                INI configuration
|           +-- operation tables
|           `-- language, license, and serial data
`-- PE overlay                                        absolute OverlayOffset
    +-- marker: 4A 47 54 46 55 56 51 60 54 55 42 53 55
    +-- observed header field                          8 bytes; semantics unresolved
    `-- 7z payload                                    37 7A BC AF 27 1C
        `-- installed files                           Base64 UTF-16LE path segments
```

The configuration and payload archives are independent. Resource bounds come from the PE resource directory. Payload bounds come from the 7z start header and next-header coordinates. The payload candidate must contain at least one canonical encoded path segment; this rejects unrelated 7z archives appended to or embedded in the executable.

## Container headers

### Microsoft Cabinet configuration

The legacy route reads the standard unreserved CFHEADER fields needed to bound the cabinet. All integers below are little-endian and offsets are cabinet-relative.

```text
Offset  Size  Field
------  ----  ----------------------------------------------------------
0x00       4  Signature: 4D 53 43 46, "MSCF"
0x04       4  Reserved1
0x08       4  Cabinet byte length, cbCabinet
0x0C       4  Reserved2
0x10       4  First CFFILE table offset, coffFiles
0x14       4  Reserved3
0x18       1  Format minor version
0x19       1  Format major version
0x1A       2  Folder count
0x1C       2  File count
0x1E       2  Flags
0x20       2  Set identifier
0x22       2  Cabinet index
```

Cabinet folder and file parsing is delegated to the shared cabinet implementation. The InstallForge layer imposes a 16 MiB configuration limit, 65,536 entry limit, and 256 MiB per-entry limit in addition to cabinet-level validation.

### ZIP payload range

The legacy payload is selected as a complete ZIP archive rather than treating the remainder of the executable as ZIP data. The shared range locator validates local records, central-directory coordinates, and the end-of-central-directory record.

```text
ZIP range
+-- local file records                                50 4B 03 04
+-- compressed file data
+-- central directory                                50 4B 01 02
`-- end of central directory                         50 4B 05 06
```

The parser accepts a ZIP range only when it starts after the validated configuration cabinet and exposes at least one payload entry.

### 7z configuration and payload

The modern route uses the standard 32-byte 7z signature header. Integers are little-endian and coordinates after the signature header are relative to its end.

```text
Offset  Size  Field
------  ----  ----------------------------------------------------------
0x00       6  Signature: 37 7A BC AF 27 1C
0x06       1  Major version
0x07       1  Minor version
0x08       4  Start-header CRC32
0x0C       8  Next-header offset, uint64
0x14       8  Next-header size, uint64
0x1C       4  Next-header CRC32
0x20       *  Packed streams and next header
```

The shared 7z range locator validates header CRCs, next-header bounds, and archive extent before SharpCompress opens the bounded range. InstallForge accepts the resource archive only when it contains `SC.dat`. It accepts a modern payload only when entry names exhibit the canonical InstallForge Base64 path encoding.

## Configuration archive

### SC.dat

`SC.dat` is an INI document. Legacy media normally contains only `[Setup]`; modern media also contains `[SetupArchive]`. Text decoding accepts UTF-8, UTF-16 BOMs, strict BOM-less UTF-8, and Windows-1252 fallback. Repeated keys use the last compiled value.

Important `[Setup]` keys consumed by the parser include:

| Key | Compiled meaning used by the parser |
| --- | --- |
| `Appname` | Product display name and modern built-in uninstall-key name |
| `Version` | Display version |
| `Company` | Publisher |
| `Website1` | Publisher/help URL and modern ARP `HelpLink` |
| `InstallDir` | Default installation directory expression |
| `Uninstaller` | Enables generation of the built-in uninstaller and ARP registration |
| `UninstallerFilename` | Configured uninstaller basename or filename; defaults to `Uninstall` when empty |
| `Uninstaller_VW` | Selects 64-bit uninstall registry view when true; otherwise 32-bit view |
| `UninstallerUseCustomDisplayIcon` | Selects an explicit display icon instead of the uninstaller path |
| `UninstallerCustomDisplayIcon` | Custom ARP display-icon expression |
| `Addition` | Enables the finish-page launch action |
| `ProgramRun` | Main or finish-page executable expression |
| `ProgramRunArguments` | Arguments passed to the configured program |

Modern `[SetupArchive]` includes `SetupArchiveFilesUncompressedSize`. The runtime and parser convert it to ARP `EstimatedSize` with `ceil(bytes / 1024)`.

Values not interpreted by the parser remain available in the returned `Configuration` object. Their presence is not assigned a semantic meaning without compiled-media or runtime evidence.

## Operation tables

Operation files are separate archive entries. Records are concatenated without a count header. Text fields use CRLF terminators. A table ending on a partial record is malformed.

### Registry.dat

`Registry.dat` mixes four text fields with a binary removal flag. The record repeats to end of file.

```text
+----------------------+ record start
| Root                 | UTF-8/legacy text + CRLF
+----------------------+
| Key                  | UTF-8/legacy text + CRLF
+----------------------+
| Name                 | UTF-8/legacy text + CRLF; empty means default value
+----------------------+
| Value                | UTF-8/legacy text + CRLF
+----------------------+
| RemoveOnUninstall    | uint32 LE; zero=false, nonzero=true
+----------------------+ next record
```

Literal uninstall-key writes are grouped by root and key. A group becomes ARP evidence only when it contains `DisplayName`. The observed custom table writes every value as `REG_SZ`; therefore `SystemComponent="1"` does not hide a row because Windows and WinGet require a numeric value for that marker. Controlled 1.6.1 media confirms that custom HKLM writes from the x86 setup runtime land in the 32-bit registry view. HKCU uninstall keys are view-shared and retain no single view label. `Uninstaller_VW` applies to the built-in uninstaller row and is not applied to custom records.

### Variables.dat

Custom variables use five CRLF-delimited text fields per record.

```text
Name
RegistryRoot
RegistryKey
RegistryValueName
DefaultValue
```

The runtime reads the configured registry value and falls back to `DefaultValue`. Because the registry value can replace that default, static projection retains both as evidence but does not substitute a custom variable into authoritative ARP, association, or installation-path fields. Since InstallForge 1.4, custom variables are referenced as `[Name]`; earlier projects may use the older angle-bracket form. The resolver recognizes both forms and stops after eight passes to bound recursive substitutions.

### Commands.dat

Custom command records use four text fields.

```text
Type
Command
Arguments
Options
```

The parser resolves deterministic path constants in `Command` and `Arguments` and returns the record as evidence. It never invokes the command. Official documentation defines `Execute Application` and `Shell Execute` command types, `-wait` as waiting for the child process, and `-hide` as starting the child hidden. The parser retains `Options`, exposes exact `OptionTokens`, `WaitForExit`, `Hidden`, and `UnknownOptions`, and emits a structured diagnostic for unknown types or tokens. Empty final option fields remain valid record fields rather than being mistaken for truncated tables.

### Desktop.dat and Startmenu.dat

Shortcut records evolved while retaining line-oriented framing.

| Generation | Fields per record |
| --- | --- |
| InstallForge 1.2.2 | `Target`, `Name` |
| InstallForge 1.2.3 through 1.2.9 | `Target`, `Name`, `Arguments` |
| InstallForge 1.3 and later | `Target`, `Name`, `Arguments`, `IconPath`, `IconIndex` |

The table name selects the destination class: desktop or Start menu. The compiled `DFA` value selects per-user versus common Desktop placement, and `SFA` does the same for Start menu placement. Controlled 1.6.1 installation proves that `DFA=1` writes below `C:\Users\Public\Desktop` and `SFA=1` writes below `C:\ProgramData\Microsoft\Windows\Start Menu\Programs`; zero uses the current user's corresponding folder. Each returned shortcut therefore includes `AllUsers`, `Scope`, and `ScopeEvidence`.

### OS.dat and other entries

`OS.dat` is a line-oriented `Name=0|1` requirement dictionary. Names vary across releases, from `Win95` and `WinXP` in early media to descriptive names such as `Windows 11` in current media. The parser reports the compiled dictionary without mapping it to WinGet `MinimumOSVersion`.

`languages.dat` lists one compiled language name per line. `.ifl`, `licence.rtf`, `Serials.dat`, splash resources, and other configuration entries remain catalog evidence unless a parser output explicitly consumes them.

## Path encoding and constants

Modern payload path components are Base64-encoded UTF-16LE, optionally including a trailing UTF-16 null. Decoding is accepted only when re-encoding the decoded value reproduces the original component. This avoids corrupting ordinary filenames that happen to use Base64 characters.

```text
Encoded component: RQB4AGEAbQBwAGwAZQAuAGUAeABlAA==
UTF-16LE bytes:   "Example.exe\0"
Decoded component: Example.exe
```

The resolver maps deterministic predefined constants to manifest-safe Windows environment variables, including Program Files, Common Files, ProgramData, AppData, LocalAppData, user profile folders, Start menu folders, Windows, System32, SysWOW64, and Fonts. The authoritative predefined-constant list is maintained in the InstallForge documentation. Unknown constants remain unresolved and are excluded from ARP or association claims that require literal registry paths.

## Modern Apps and Features behavior

Controlled InstallForge 1.6.1 installations prove the following built-in uninstaller mapping:

```text
Registry hive       HKLM
Registry view       64-bit when Uninstaller_VW=1, otherwise 32-bit
Subkey name         Appname
ProductCode         Appname
DisplayName         Appname
DisplayVersion      Version
Publisher           Company
UninstallString     <resolved InstallDir>\<UninstallerFilename>
DisplayIcon         custom icon when enabled, otherwise UninstallString
InstallLocation     resolved InstallDir
HelpLink            Website1
EstimatedSize       ceil(SetupArchiveFilesUncompressedSize / 1024)
NoModify            1
NoRepair            1
SystemComponent     0
```

The runtime preserves the configured uninstaller name in `UninstallString` and `DisplayIcon`. If the project says `RemoveProbe`, those registry values omit `.exe` even though the installed executable has that extension. The parser mirrors the registry value rather than correcting it to a filesystem filename.

The native setup executable requests administrator elevation and writes the built-in row to HKLM even when `InstallDir` points below LocalAppData. Scope therefore follows compiled ARP and execution-level evidence, not the apparent destination path.

Custom `Registry.dat` operations can create additional uninstall rows. Visible rows become separate Apps and Features evidence. If several visible rows exist, the parser returns all rows but leaves the scalar ProductCode unresolved rather than choosing one arbitrarily.

## Legacy Apps and Features behavior

The 1.2.2 runtime contains no built-in uninstall-registration path. A controlled installation creates `Uninstall.exe` and `uninstall.dat` but no uninstall key in HKLM or HKCU, so `Uninstaller=1` proves only that uninstall support is packaged. The parser returns no ProductCode or Apps and Features entry for this route.

The 1.2.6.2 and 1.3.2 runtimes contain the structured uninstall-registration code path and produced this tuple in controlled installations:

```text
Registry hive       HKLM
Registry view       32-bit for the verified x86 runtimes
Subkey name         Appname
ProductCode         Appname
DisplayName         Appname
DisplayVersion      Version
Publisher           Company
UninstallString     <resolved InstallDir>\<UninstallerFilename>.exe
DisplayIcon         UninstallString
HelpLink            Website1
```

These legacy rows omit the modern `InstallLocation`, `InstallDate`, `EstimatedSize`, `NoModify`, and `NoRepair` values. If `UninstallerFilename` lacks `.exe`, the legacy runtime appends it; modern media preserve the configured ARP string without adding the extension.

## Installability

The InstallForge builder command line is not the generated setup command line. Options such as `-i`, `-o`, and `--quiet` build a setup and must never be suggested as installer switches.

No supported unattended switch was found in official documentation or controlled runtime behavior. `/S` and `/silent` left the 1.6.1 wizard interactive and produced no installed state when the wizard was not completed. The standard runtime is therefore reported as interactive-only. A publisher-specific outer wrapper requires separate structural and dynamic evidence.

Completed interactive installations of 1.2.2, 1.2.6.2, 1.3.2, and controlled 1.6.1 media returned process exit code `0`, which is already WinGet's generic success default and therefore needs no `InstallerSuccessCodes` entry. Canceling from the welcome page also returned `0` in controlled 1.3.2 and 1.6.1 runs. No `ExpectedReturnCodes` entry can distinguish that cancellation from success, so dynamic validation must verify installed state rather than trust the process status alone. Failure codes remain uncharacterized.

## Detection invariants

Modern detection requires all of the following:

1. A valid PE image with a bounded overlay.
2. An `RCDATA` resource named `SETUPCONFIGURATION` containing a valid bounded 7z archive.
3. A usable `SC.dat` whose `[Setup]` section contains non-empty `Appname`.
4. A bounded overlay 7z candidate with at least one canonical encoded path component for full payload support.

Legacy detection requires all of the following:

1. A valid PE image with a bounded overlay.
2. A bounded `MSCF` cabinet candidate near the overlay start.
3. A usable `SC.dat` in that cabinet.
4. A complete ZIP range after the cabinet for full payload support.

A valid configuration without a payload remains family evidence and produces an incomplete-extraction diagnostic. Product strings, URLs, PE version fields, or isolated archive signatures are insufficient by themselves.

## Extraction and safety

`Expand-InstallForgeInstaller` reuses the validated layout and opens only the selected bounded payload range. Omitting `Name` selects all installed payload files; a supplied decoded path or wildcard selects matching entries. Modern 1.4.x GZip/TAR and 1.5+ 7z archive names are decoded before selection and safe-path resolution.

Extraction enforces resolved source and destination paths, safe relative paths, duplicate-output tracking, collision policy, 65,536 entries, 256 MiB per entry during cataloging, a 4 GiB archive bound, and a caller-configurable aggregate output limit that defaults to 16 GiB. The shared archive layer adds CRC, decompression, traversal, and stream-ownership checks.

InstallForge 1.4+ places its generated uninstaller in the installed-file archive as an ordinary root payload record, even when `SC.dat` omits the physical `.exe` suffix from the ARP command. `GeneratedUninstallerEntry` identifies that record and `Expand-InstallForgeInstaller` exports it normally. Verified 1.2.x-1.3.x media generate `Uninstall.exe` and `uninstall.dat` at installation time instead; those runtime-generated legacy bytes cannot be recovered from the installed-file archive. Configuration resources and operation tables are not exported by normal payload extraction.

## Performance model

One top-level parse computes one logical layout containing the PE overlay, configuration route, configuration-entry map, payload range, decoded tables, ARP projection, and payload catalog. Bounded ranges may be reopened when the selected archive API requires independent seeking or when payload binaries are selectively materialized for PE analysis. Metadata readers delegate to `Get-InstallForgeInfo`, so callers should invoke it once and reuse the result rather than call several `Read-*FromInstallForge` functions.

The parser does not buffer the complete installer or payload. The small configuration archive is capped at 16 MiB and materialized once because several tables are correlated. Payload entries are cataloged through a bounded archive view and materialized only during extraction. Architecture and dependency analysis first selects an exact configured `ProgramRun` executable. If that path is absent or ambiguous, it analyzes the complete payload EXE set, excluding the generated uninstaller, only when all executables fit within the 32-file and 512 MiB limits. The parser never samples an oversized set. A complete mixed-architecture result remains an architecture set and suppresses the scalar `Architecture`; it does not fall back to the outer x86 setup stub.

## Known gaps

- Registry-backed custom variables, command conditions, and other runtime-derived expressions cannot be resolved statically unless a literal default is sufficient.
- Runtime-generated uninstallers from verified 1.2.x-1.3.x media are not reconstructed. Modern 1.4+ uninstallers are payload records and are fully extractable.
- Failure exit codes are not proven across releases. Cancellation returned success code `0` in the verified 1.3.2 and 1.6.1 runtimes, but remains untested in other generations.
- InstallForge releases older than 1.2.2 and structurally different future engines have no verified fixtures.

Two cached Wayback responses are fixture limitations rather than parser gaps: both responses are truncated at exactly 1 MiB. The 1.4 response is correctly rejected by GZip CRC/ISIZE validation. The 1.3.2 response retains complete configuration as partial metadata and reports `InstallForge.Extraction.PayloadMissing`, but cannot be extracted or treated as a complete installer.

## Implementation mapping

- `Modules/PackageModule/Libraries/Installers/InstallForge.psm1`: structural routing, configuration and operation decoding, metadata and ARP projection, detection, and extraction.
- `Modules/PackageModule/Libraries/Infrastructure/Cabinet.psm1`: standard Microsoft Cabinet enumeration and bounded export.
- `Modules/PackageModule/Libraries/Infrastructure/Archive.psm1`: ZIP and 7z range discovery, archive entry APIs, collision handling, and bounded extraction.
- `Modules/PackageModule/Libraries/Infrastructure/PE.psm1`: PE layout, overlay, resources, execution level, and architecture evidence.

## Representative fixtures

Durable fixtures are stored outside the repository under `Dumplings-TestFixtures/Builders/InstallForge`. The regression set includes archived 1.2.2, 1.2.6.2, 1.2.7, 1.2.9.2, 1.3.2, 1.4.2, and 1.4.4 builder installers; official 1.5.0, 1.6.0, and 1.6.1 GitHub release assets; and controlled 1.6.1 baseline, operation-heavy, command-option, shortcut-scope, and custom-ARP projects.

The official GitHub assets are pinned in tests by SHA256. Proprietary installers and extracted payloads are not committed to Dumplings.

## Source references

- [InstallForge release repository](https://github.com/soner-boztas/installforge/releases)
- [InstallForge documentation](https://installforge.net/docs/)
- [InstallForge release notes](https://installforge.net/docs/release-notes/)
- [InstallForge command-line builder](https://installforge.net/docs/using-installforge/command-line-interface/)
- [InstallForge predefined constants](https://installforge.net/docs/getting-started/predefined-constants/)
- [InstallForge custom variables](https://installforge.net/docs/how-tos/using-custom-variables/)
- [InstallForge custom commands](https://installforge.net/docs/how-tos/using-custom-commands/)
- [InstallForge custom Apps and Features icon](https://installforge.net/docs/how-tos/using-custom-display-icon-in-windows-programs-and-features/)
- [Archived ForgeSoft InstallForge setup captures](https://web.archive.org/web/*/http://download.forgesoft.net:80/?i=IFSetup)
- [Archived InstallForge setup captures](https://web.archive.org/web/*/https://installforge.net/downloads/?i=IFSetup)
