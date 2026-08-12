# Kachina internals

## Scope

Kachina is a native Tauri installer whose executable carries an appended record stream. The installed application payload is not a conventional archive: each metadata-backed file is an independent Zstandard record, while control JSON, the compact index, patches, and optional runtime installers use the same outer TLV framing. The parser opens the PE once, locates the record stream after the final PE section, and performs random reads through bounded ranges.

The upstream Kachina repository had no declared license when this implementation was written. This document records observable structures and runtime behavior. The PackageModule implementation is independently written under Apache-2.0.

## Container layers

```text
Kachina installer executable
+-- DOS header and stub
|   +-- MZ / PE linkage
|   `-- !KachinaInstaller! marker followed by five UInt32BE fields
+-- PE image
|   +-- native Tauri loader and WebView UI
|   +-- resources and version information
|   `-- final section boundary
`-- Kachina TLV stream
    +-- control records
    |   +-- configuration JSON
    |   +-- optional UI image
    |   +-- optional compact index
    |   `-- optional release metadata JSON
    +-- application records
    |   +-- one Zstandard frame per unique payload hash
    |   `-- one hash may map to several installed paths
    +-- update records
    |   `-- <oldHash>_<newHash> HDiff patches
    `-- appended raw records
        `-- optional .NET or VC runtime installers
```

The physical order is part of generation detection. The compact index is an accelerator and integrity check; the runtime still scans all TLVs, so appended runtime records may be absent from the index.

## PE marker and pre-index

The ASCII marker `!KachinaInstaller!` occupies 18 bytes in the DOS stub. Five unsigned big-endian 32-bit fields follow it.

```text
Offset from marker  Size  Field
------------------  ----  -------------------------------------------------------
0x00                  18  ASCII !KachinaInstaller!
0x12                   4  Record-stream base offset
0x16                   4  Generation-dependent first control-record raw length
0x1A                   4  Generation-dependent second control-record raw length
0x1E                   4  Generation-dependent third control-record raw length
0x22                   4  Metadata record raw length
```

Early indexed builders order the four sizes as INDEX, CONFIG, IMAGE, META. Corrected builders order them as CONFIG, IMAGE, INDEX, META. The first indexed builder can count the INDEX TLV header twice in the first size field. Config-only and reconstructed updater/uninstaller executables clear all five fields to zero but retain the marker text.

The parser treats the pre-index as supporting evidence. Sequential TLVs and their validated offsets are authoritative because historical pre-index writers changed ordering and one release had the double-counting defect.

## TLV framing

Legacy records use `21 49 4E 53` (`!INS`). Indexed and current records use `21 49 4E 00` (`!IN\0`). All integer fields are unsigned and big-endian.

```text
Record-relative offset  Size        Field
----------------------  ----------  -----------------------------------------------
0x00                    4           Magic: !INS or !IN\0
0x04                    2           NameLength:u16 BE
0x06                    NameLength  Name: strict UTF-8
0x06 + NameLength       4           ContentLength:u32 BE
0x0A + NameLength       ContentLength Content bytes
```

The next record begins immediately after the content. There is no padding or alignment. A valid sequence reaches the end of the installer file. The parser rejects invalid UTF-8 names, empty or oversized names, truncated content, excessive record counts, and non-TLV trailing bytes.

## Format generations

### Legacy scan

Legacy media uses `!INS` and has no pre-index or compact index. `.config.json` and `.metadata.json` are required, while `.image` is optional. Hash-named payload and patch records follow the control records.

### Early indexed

Early indexed media uses `!IN\0`, places `\0INDEX` first, and follows it with `\0CONFIG`, optional `\0IMAGE`, `\0META`, payload, patch, and appended records. Its pre-index sizes use INDEX, CONFIG, IMAGE, META ordering.

### Current indexed

Current indexed media places `\0CONFIG` first, then optional `\0IMAGE`, `\0INDEX`, `\0META`, and data records. Its pre-index sizes use CONFIG, IMAGE, INDEX, META ordering. BetterGI 0.40 and 0.63 artifacts tested by Dumplings both use this corrected physical order.

### Config-only updater

Config-only media has a valid `\0CONFIG` record but no `\0INDEX` or `\0META`; the five pre-index fields are zero. The installer resolves metadata and payload from its configured source at runtime. Static analysis can recover product identity, default path, ARP behavior, switches, and UAC strategy, but it must leave target version and payload-derived fields unresolved.

## Compact index

The `\0INDEX` content is a packed sequence with no entry count or terminator. Offsets are relative to the first physical TLV and point to record content, not record magic.

```text
Index entry
+-----------------------------+
| NameLength:u8               |
+-----------------------------+
| Name[NameLength]:UTF-8      |
+-----------------------------+
| ContentLength:u32 BE        |
+-----------------------------+
| ContentOffset:u32 BE        | relative to first TLV
+-----------------------------+
```

Every index item must match a sequential record with the same name, content length, and absolute content offset. The index may omit appended records. An item that points outside a TLV boundary is structural corruption and rejects the installer.

## Configuration JSON

The parser requires nonempty `appName`, `publisher`, `regName`, and `exeName` fields. Common fields include `source`, legacy `dfsPath`, `uninstallName`, `updaterName`, `programFilesPath`, `uacStrategy`, `runtimes`, `userDataPath`, `title`, `description`, and `windowTitle`.

`regName` is the uninstall-key name and therefore the parser's `ProductCode`. `programFilesPath` forms the default `%ProgramFiles%` destination. `runtimes` contains tags understood by Kachina's prerequisite handler. The current runtime supports `Microsoft.DotNet.DesktopRuntime.*`, `Microsoft.DotNet.Runtime.*`, `Microsoft.VCRedist.2015+.x64`, and `Microsoft.VCRedist.2015+.x86`.

## Release metadata

The `\0META` or `.metadata.json` object normally contains `tag_name`, `hashed`, `patches`, `deletes`, repository metadata, and an `installer` object. Each `hashed` item supplies an installed `file_name`, expanded `size`, and one or more source hash labels.

An `md5` value is a proven MD5 checksum and is validated after expansion. Current metadata also uses an `xxh` field, but a 128-bit string shape alone does not prove a specific xxHash variant. Dumplings preserves it as an opaque source-defined record identity and does not claim an algorithm.

Several paths can reference one hash-named record. Kachina stores the compressed bytes once. The extractor decompresses the first selected path and copies its verified output to the other selected destinations while still charging every installed copy against the aggregate output limit.

## Payload and patches

Normal hash-named records contain one Zstandard frame. The metadata `size` is the required decompressed byte count. Extraction uses a bounded record substream, a streaming ZstdSharp decoder, an aggregate output limit, and an exact-length check that rejects both short and long output. MD5-backed entries receive a final content check.

Patch records are named `<fromHash>_<toHash>` and contain HDiff data. They describe update routes and are not installed files. The current parser catalogs them but does not apply them. `-RawEntries` can export their physical bytes for separate static inspection.

## Runtime installers

Kachina checks `config.runtimes` before installing the application. If a TLV has the exact runtime tag as its name, the runtime passes that record's absolute offset and length to the prerequisite installer path. If no matching TLV exists, Kachina downloads the runtime from the source encoded by its runtime handler.

Appended runtime installers are raw executable bytes rather than Zstandard application records. They are not part of `metadata.hashed`, are commonly omitted from `\0INDEX`, and must not appear in default installed-file extraction. Dumplings exposes them through `EmbeddedRuntimePackages` and `-RawEntries`. A configured tag without a record remains a downloadable `RuntimePackage` with `IsEmbedded=false`.

## Generated updater and uninstaller

The installed updater and uninstaller are reconstructed from the original executable prefix ending after CONFIG and optional IMAGE. Kachina then writes zero to the 20-byte pre-index field area. It does not remove the 18-byte marker. The generated executable can load its compiled configuration but has no embedded metadata or payload.

```text
generated tool
+-- original bytes from file offset 0
+-- DOS marker retained
+-- five pre-index UInt32BE values replaced with zero
+-- CONFIG TLV retained
`-- optional IMAGE TLV retained
```

## Command line

The native command-line parser defines `-D <path>` for installation directory, `-I` for noninteractive installation with progress, `-S` for silent installation, `-O` to force online installation, and `-U` for uninstall. Hidden source and mirror parameters are runtime implementation details and are not manifest switches.

WinGet has no Kachina-specific defaults because the manifest type is generic `exe`. The authoring projection therefore includes the proven silent, progress, and install-location switches.

## UAC and scope

Kachina defaults to `%ProgramFiles%\<programFilesPath>`. The `force` strategy always requests elevation. `prefer-admin` requests elevation unless the target is in a recognized user location. `prefer-user` requests elevation only when the current user cannot write the target.

The registry writer chooses HKLM when elevated and HKCU otherwise. A non-force installer can therefore write a user ARP entry when `-D` selects an eligible user path and the process stays unelevated. The default Program Files route remains machine scope.

## ARP registration

After metadata is available, Kachina creates `SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\<regName>` in the selected hive. It writes `DisplayName`, `DisplayVersion`, `UninstallString`, `InstallLocation`, `DisplayIcon`, `Publisher`, `EstimatedSize`, `NoModify=1`, `NoRepair=1`, and `InstallerMeta` containing serialized metadata.

The built-in runtime also creates Start menu shortcuts for the application and uninstaller. A desktop shortcut is conditional on the installer's UI choice. The reviewed source does not define built-in protocol registration, file-extension registration, PATH changes, autorun, firewall rules, or certificate installation.

## Architecture and dependencies

The outer Tauri PE identifies the installer host, not necessarily the installed application. Dumplings selectively expands the configured main executable plus bounded adjacent DLL and JSON sidecars, then applies the shared PE architecture and dependency analyzers. This detects native architecture, managed AnyCPU behavior, VC runtime imports, and framework-dependent .NET evidence without materializing the whole package.

Configured Kachina runtime delivery remains separate from application dependency inference. The parser reports both sources of evidence and does not mutate WinGet dependencies automatically.

## Parser limits and gaps

The parser limits record searches, names, record counts, JSON and index sizes, selective analysis bytes, extraction entries, and aggregate output. It validates PE layout, every physical range, index boundaries, destination containment, collisions, Zstandard output length, and proven MD5 checks. Caller-owned streams remain open and random-access helpers restore their positions.

HDiff patch application is not implemented because patches are update inputs rather than installed files. Config-only media is not fetched. The source-defined `xxh` identity is not assigned a concrete algorithm without structured proof. Runtime prerequisite executables are exported only in raw mode and are never executed on the host.

## Implementation mapping

- `Modules/PackageModule/Libraries/Installers/Kachina.psm1`: generation detection, TLV/index parsing, metadata and ARP projection, payload extraction, and generated tools.
- `Modules/PackageModule/Libraries/Infrastructure/Archive.psm1`: bounded Zstandard decoding through the pinned ZstdSharp assembly.
- `Modules/PackageModule/Libraries/Infrastructure/InstallerAnalyzer.psm1`: strict family routing before MicaSetup and generic Tauri hints.
- `Modules/PackageModule/Libraries/WinGet/WinGetAnalysis.psm1`: WinGet generic-EXE defaults and source-proven switches.

## Fixtures

- AkashaNavigator 1.4.0, SHA256 `F6A0826E59B87C80DBFAE33492A5560B3CC76A30FBC3C854478771D7CBB0629F`: corrected indexed order, x64 payload, patch record, and downloadable runtimes.
- BetterGI 0.40.0, SHA256 `C4683C080827F7A1C70CD2BFA2177B976FF4C5FAF07A2D6F732A5045B8882203`: production corrected indexed order.
- BetterGI 0.63.0, SHA256 `777EB7605A6E4491EDCA1D327A32770D4A1FDCD102E699F842D320AA29A938B9`: large corrected indexed payload with configured downloadable .NET Desktop Runtime 8 and VC++ 2015+ x64 requirements.
- Generated media covers legacy scan, early indexed order, config-only layout, appended runtime records, malformed JSON, invalid offsets, truncation, traversal, collisions, and size/hash failures.

## Source references

- [YuehaiTeam/kachina-installer](https://github.com/YuehaiTeam/kachina-installer)
- [Runtime TLV and index reader](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/local.rs)
- [Pack writer](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/builder/pack.rs)
- [Append writer](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/builder/append.rs)
- [Builder pre-index replacement](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/builder/replace_bin.rs)
- [Installer configuration](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/installer/config.rs)
- [Runtime installation](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/installer/runtimes.rs)
- [ARP registry writer](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/installer/registry.rs)
- [Payload installer](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/ipc/install_file.rs)
- [Command-line arguments](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/cli/arg.rs)
