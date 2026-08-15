# Qt Installer Framework internals

This reference describes the Windows media produced by Qt Installer Framework (Qt IFW). For manifest authoring, use the [Qt Installer Framework workflow](../../families/qt-installer-framework/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

Qt IFW does not preserve a reliable open-source or commercial edition identifier in generated media. The useful static identity consists of the Qt IFW framework version, the Qt runtime version when embedded, the binary-content generation, the media role, and the selected parser routes.

The parser covers Windows media from the first source-tagged 1.2 layout through 4.11. It recognizes both executable and separate-data cookies and the installer, uninstaller, updater, and package-manager markers. `Get-QtInstallerFrameworkInfo` accepts only installer media; `Get-QtInstallerFrameworkFormatInfo` can diagnose every role.

| Framework range | Format generation | Package index | Configuration and runtime capabilities |
| --- | --- | --- | --- |
| 1.2-1.x | `LegacyComponentIndex` | Component index and per-component archive tables | Legacy `UninstallerName` keys, GUI runtime, ProductName ARP key |
| 2.0-3.1.1 | `BinaryContent` | Resource collection manager | `MaintenanceToolName`, ProductUUID, GUI runtime |
| 3.1.2-3.x | `BinaryContent` | Resource collection manager | Embedded IFW/Qt version string and optional PE version evidence |
| 4.0-4.1 | `BinaryContent` | Resource collection manager | Command-line interface and `DisableCommandLineInterface` |
| 4.2-4.11 | `BinaryContent` | Resource collection manager | Command-line interface and libarchive-era selectable archive formats |

The 2.0 binary-format overhaul changed the semantic model from `ComponentIndex` to `ResourceCollectionManager`, while retaining the qint64 count, name, range, and trailing-count framing. Exact embedded version evidence normally selects the meaning of the primary index. The unversioned 1.2 launcher is distinguished using legacy configuration keys and complete index validation.

## Binary structure

Every Windows installer starts with a PE launcher. Qt IFW appends its metadata, operations, package data, index, and trailer after the launcher. Trailer offsets are relative to `EndOfExecutable`, not absolute file offsets.

```text
Qt IFW 1.x
PE installerbase
`-- binary content
    +-- metadata RCC range[ResourceCount]
    +-- operation records
    +-- component data and archive bytes
    +-- ComponentIndex
    `-- trailer and cookie

Qt IFW 2.0+
PE installerbase
`-- binary content
    +-- metadata RCC range[ResourceCount]
    +-- operation records
    +-- resource-collection data and package archives
    +-- ResourceCollectionManager index
    `-- trailer and cookie
```

### Common trailer

The terminal trailer is read backward from the cookie. Every integer and range member is a signed qint64 in little-endian order.

```text
Offset relative to trailer start  Size                 Field
-------------------------------  -------------------  -------------------------------------------
0x00                             16                   Primary index offset and length
0x10                             16 * ResourceCount   Metadata RCC offset and length pairs
variable                         16                   Operations offset and length
variable                          8                   ResourceCount
variable                          8                   BinaryContentSize
variable                          8                   Media marker
variable                          8                   Magic cookie
```

The primary index field points to `ComponentIndex` in 1.x and `ResourceCollectionManager` in 2.0+. `BinaryContentSize` reaches from `EndOfExecutable` through the cookie and therefore determines the relative-offset base.

The executable cookie is `F8 68 D6 99 1C 0A 63 C2`, which represents little-endian `0xC2630A1C99D668F8`. A separate `.dat` content file uses `F9 68 D6 99 1C 0A 63 C2`.

| Marker | Value | Meaning |
| --- | --- | --- |
| Installer | `0x12023233` | Initial installation media |
| Uninstaller | `0x12023234` | Maintenance tool in uninstall mode |
| Updater | `0x12023235` | Maintenance tool in update mode |
| Package manager | `0x12023236` | Maintenance tool in package-manager mode |

### Length-prefixed values and ranges

Qt IFW serializes byte arrays as an eight-byte signed length followed by that many bytes. Names are UTF-8 unless the enclosing structure defines another encoding.

```text
+----------------------+ 0
| Length               | qint64 LE
+----------------------+ 8
| Bytes                | Length bytes
+----------------------+
```

A serialized range is `[Start:qint64 LE][Length:qint64 LE]`. Index ranges are relative to the binary-content base and are rebased only after `BinaryContentSize` validates.

### Performed operations

The operations range records actions already performed by a maintenance tool. Installer media normally has a zero count, while uninstaller, updater, and package-manager media can carry operation XML used to reconstruct undo state.

```text
Operations block
+----------------------+ OperationCount: qint64 LE
| OperationCount       |
+----------------------+ repeated OperationCount times
| OperationName        | qint64-length-prefixed UTF-8
| OperationData        | qint64-length-prefixed UTF-8 XML
+----------------------+
| OperationCount       | repeated footer; must match header
+----------------------+
```

Each `OperationData` document uses the envelope emitted by `KDUpdater::UpdateOperation::toXml()`:

```xml
<operation>
  <arguments>
    <argument>first literal argument</argument>
  </arguments>
  <values>
    <value name="oldvalue" type="QString">backup evidence</value>
  </values>
</operation>
```

Arguments have already passed Qt IFW path relocation before serialization. An optional `UNDOOPERATION` marker separates perform arguments from rollback-control arguments. Scalar QVariant values are decoded conservatively; Qt `QDataStream`-encoded lists, maps, hashes, byte arrays, and generic variants remain marked encoded because their backup state is not needed to identify the operation's forward system effect.

The parser bounds the segment and count, parses XML with DTD and external resolution disabled, validates both strings against the declared segment, and requires exact record consumption. It keeps `RawXml` and the legacy `Data` property for auditability, then projects source-defined operations into `FileSystemEffects`, `RegistryWrites`, `ShortcutEffects`, `EnvironmentEffects`, and `ExecutionEffects`. Unknown operations remain in `Operations` with a warning rather than receiving guessed semantics. No operation is executed.

Windows `RegisterFileType` writes are expanded into their HKCU or HKLM `Software\Classes` values, after which the shared registry-association analyzer derives `FileExtensions`, `Protocols`, `FileAssociationEffects`, and `ProtocolEffects`. `GlobalConfig` can also produce literal native registry writes; `Settings` always represents an INI-format filesystem mutation in current Qt IFW source. Environment-variable records distinguish persistent HKCU/HKLM writes from process-only values.

Qt IFW registers its maintenance tool outside the performed-operation stream in `PackageManagerCorePrivate::registerMaintenanceTool()`. The parser therefore returns that source-defined registration separately as `AppsAndFeaturesEffects` and `AppsAndFeaturesEntries`, while including its individual values in `RegistryWrites`. A missing modern `ProductUUID` remains unresolved because Qt generates the uninstall-key UUID only while installing.

### Legacy component index

Qt IFW 1.x writes component data before the component index. Each component range contains an archive descriptor table followed by the archive bytes.

```text
ComponentIndex
+----------------------+ ComponentCount: qint64
| ComponentCount       |
+----------------------+ repeated ComponentCount times
| ComponentName        | qint64-length-prefixed UTF-8
| ComponentRange       | relative start and length
+----------------------+
| ComponentCount       | repeated footer; must match header
+----------------------+

ComponentRange
+----------------------+ ArchiveCount: qint64
| ArchiveCount         |
+----------------------+ repeated ArchiveCount times
| ArchiveName          | qint64-length-prefixed UTF-8
| ArchiveRange         | relative start and length
+----------------------+
| Archive bytes        | ranges point into this component range
+----------------------+
```

The parser requires exact component-index consumption, matching header/footer counts, bounded archive counts, and archive ranges wholly contained by their component range.

### Modern resource collections

Qt IFW 2.0 replaced components with named resource collections. The serialized framing remains deliberately similar.

```text
ResourceCollectionManager index
+----------------------+ CollectionCount: qint64
| CollectionCount      |
+----------------------+ repeated CollectionCount times
| CollectionName       | qint64-length-prefixed UTF-8
| CollectionRange      | relative start and length
+----------------------+
| CollectionCount      | repeated footer; must match header
+----------------------+

CollectionRange
+----------------------+ ResourceCount: qint64
| ResourceCount        |
+----------------------+ repeated ResourceCount times
| ResourceName         | qint64-length-prefixed UTF-8
| ResourceRange        | relative start and length
+----------------------+
| Resource bytes       | package archives or other collection data
+----------------------+
```

The parser requires exact collection-index consumption and validates every collection and resource range before metadata scanning or extraction.

### Qt RCC metadata

Installer configuration and package metadata are commonly stored in Qt RCC resources. RCC integers are big-endian, unlike the surrounding Qt IFW trailer.

```text
RCC header
Offset  Size  Field
------  ----  ----------------------------------
0x00       4  ASCII `qres`
0x04       4  Format version, uint32 BE
0x08       4  Tree offset, uint32 BE
0x0C       4  Data offset, uint32 BE
0x10       4  Name-table offset, uint32 BE
```

Tree nodes are 14 bytes. Directory nodes contain child count and child offset. File nodes contain locale fields and an offset into the data block. Names are stored as UTF-16BE strings with a uint16 character count and a uint32 hash. A compressed file has the RCC compressed flag and contains a qCompress stream: uncompressed size in uint32 BE followed by zlib data.

The installer configuration is normally available as `:/installer-config/config.xml`. The parser reads direct `<Installer>` children and does not infer script-generated values from unrelated strings.

## Payload selection and nested execution

Legacy components and modern resource collections both associate package names with archive ranges. The archive bytes are physically embedded unless the builder creates separate DAT content or repository packages. Qt IFW passes the selected package archives to its operation engine; archive order in the binary is not by itself execution order.

Repository `Updates.xml` records use a `PackageUpdate` element. `Name` selects the component directory, `Version` prefixes each comma-separated `DownloadableArchives` value, and the resulting source path is `<repository>/<Name>/<Version><ArchiveName>`. For example, `Name=A`, `Version=1.0.0`, and `DownloadableArchives=content.7z` resolve to `A/1.0.0content.7z`. Installer configuration may supply remote URLs through `RemoteRepositories`; component scripts may add archive names through `addDownloadableArchive()`.

The DAT cookie marks a complete sidecar binary-content container. A paired DAT inherits the executable's validated format profile because it may omit launcher version strings and configuration resources. Its trailer, collection index, archive ranges, and checks are still parsed independently against the DAT stream.

Early releases normally use 7z archives. Qt IFW 4.2 moved package archive handling to libarchive and advertises `tar`, `tar.gz`, `tar.bz2`, `tar.xz`, `zip`, `7z`, and `qbsp`; the older lib7z route advertises only `7z` and `qbsp`. A `.qbsp` file is physically a 7z archive. Dumplings opens TAR, ZIP, 7z, and QBSP directly, while gzip, bzip2, and xz are explicitly decoded as bounded filters before opening the nested TAR catalog. Password-protected archives and unavailable external package data remain unresolved evidence.

Extraction writes metadata RCC files and package archives using their logical collection/component paths. It validates traversal, collisions, link entries, archive counts, declared and actual expanded sizes, and the global output limit.

## Detection invariants

A cookie or source string alone is insufficient. Detection requires a supported cookie, known media marker, valid content-size split, bounded trailer counts, valid rebased ranges, matching index header/footer counts, complete primary-index consumption, and valid nested ranges.

Exact framework versions come from the source-defined launcher strings `IFW Version: ...` or `Built with Qt Installer Framework ...`. The optional PE `FileVersion` corroborates newer media but never overrides the embedded IFW marker. The Qt runtime version comes from the `built with Qt ...` suffix when present.

An unknown version at or beyond the catalog boundary may use the modern compatibility profile only after complete structural validation. It is reported with `IsFallback` and a warning. An incompatible or malformed index returns `IsQtInstallerFramework: true`, `IsSupported: false`, and diagnostic warnings.

## Controller and component scripts

Qt IFW stores controller and component scripts as named RCC resources. Installer configuration identifies a controller through `ControlScript`; package metadata identifies component scripts through `Script`. Generated media may omit `.js` or `.qs` from a controller resource name, so discovery combines the declared resource name with structural `function Controller()` and `function Component()` evidence. A successfully decoded RCC tree is traversed by leaf resource; its enclosing binary RCC buffer is never decoded again as one synthetic script.

The parser returns each decoded script verbatim with its RCC path and inferred role. It does not pass source to QtScript, QJSEngine, Node.js, a browser, or another JavaScript runtime. This keeps parsing static and prevents an installer-controlled script from accessing the host.

An assistive assignment index scans source order for conservative single-line `var`, `let`, `const`, property, and reassignment forms. Each site retains its line and complete right-hand expression. Literal strings use a bounded JavaScript escape decoder; numbers, booleans, null, direct references to earlier resolved assignments, and config-backed one-argument `installer.value()` or `component.value()` calls can be resolved. Reassignment records are retained independently because branch conditions determine runtime state.

Concatenation, template expressions, function calls, host-object reads, environment and registry access, filesystem tests, package state, GUI state, network results, dynamic properties, multi-line expressions, and conditional outcomes remain unresolved. This is intentional: raw source remains authoritative, and unresolved manifest-critical behavior requires control-flow review or VM evidence.

Script collection is bounded to 512 resources, 1 MiB of source bytes per decoded text resource, 4,194,304 characters across returned scripts, and 16,384 indexed assignment sites. Exceeding a bound rejects the script projection instead of returning truncated source that could be mistaken for complete evidence.

## Metadata projection

For Qt IFW 1.x, the visible Windows uninstall key is the configured ProductName. From Qt IFW 2.0 onward, `ProductUUID` is the uninstall key; when absent, Qt IFW generates and persists it during installation. The parser does not invent that generated value.

`UninstallerName` and `UninstallerIniFile` are normalized to their 2.0+ names, `MaintenanceToolName` and `MaintenanceToolIniFile`. `AllUsers=true` selects HKLM; other values select HKCU. Static script mentions remain conditional evidence.

CLI availability is generation-sensitive. Releases before 4.0 do not implement the modern command interface. For 4.0+, the PE subsystem selects the GUI or console launcher, and `<DisableCommandLineInterface>true</DisableCommandLineInterface>` disables the compiled CLI.

## Bounds and malformed input

Cookie search is limited to the last 1 MiB. Metadata, collection, component, resource, and archive counts have explicit limits. Byte arrays, executable string scans, XML/RCC buffers, expanded files, and total expanded bytes are bounded before allocation or copying.

Every relative range is checked for negative values, overflow, file containment, and parent containment where applicable. Callers receive deterministic unsupported or malformed-format diagnostics rather than partially guessed metadata.

## Performance considerations

One analysis context opens the input once and passes that caller-owned seekable stream through trailer discovery, package-index validation, operation decoding, version-marker scanning, PE layout/version/subsystem evidence, RCC metadata, and text-resource analysis. Readers restore the stream position after bounded random access. Parsed PE and IFW layouts, format profile, package collections, metadata resources, package declarations, and text evidence are reused for every projected field.

This removes parser-local file-handle churn and repeated PE scans. It does not materially reduce the fresh-process baseline from loading PowerShell, PackageModule infrastructure, SharpCompress, and the GPL bridge process; compare operation-specific allocations separately from that module-loading baseline.

Large package resources are copied through bounded streams. A temporary seekable file is created only for the selected nested archive because SharpCompress requires random access. The complete installer or overlay is never materialized as a PowerShell byte array.

## Implementation parity

| Area | Status | Notes |
| --- | --- | --- |
| Executable and DAT cookies | Implemented | Both terminal cookie values are recognized |
| Installer, uninstaller, updater, package-manager roles | Implemented | Metadata projection accepts installer role only |
| Qt IFW 1.x component index | Implemented | Component/archive records and matching count footer |
| Qt IFW 2.0+ resource collections | Implemented | Complete collection/resource catalog validation |
| Exact IFW and Qt runtime version | Implemented | Embedded source markers, optional PE corroboration |
| Legacy and modern config names | Implemented | Maintenance-tool aliases normalized |
| Performed-operation records | Implemented | Secure XML envelope decoding, perform arguments, scalar values, raw XML retention, and typed static effects; no operation execution |
| Filesystem, registry, shortcut, and environment effects | Implemented | Source-defined built-in operation arguments are projected; opaque execution and unknown operations warn |
| Protocol and file-association effects | Implemented | Derived from explicit `RegisterFileType` and native registry-write evidence |
| ProductName/ProductUUID ARP rules | Implemented | Maintenance registration is reconstructed separately from operations; runtime-generated UUID remains unresolved |
| GUI/CLI capability boundary | Implemented | 4.0 catalog capability plus PE subsystem/config |
| All Qt-supported package formats | Implemented | Extraction regressions cover TAR, TAR+gzip, TAR+bzip2, TAR+xz, ZIP, 7z, and QBSP |
| Unknown future compatible media | Implemented | Requires complete modern-route validation |
| Password-protected archives | Not implemented | Returned as unsupported evidence |
| Embedded, sidecar, online, missing, and intentionally empty package data | Implemented | `Package`/`PackageUpdate`, `RemoteRepositories`, DAT cookies, adjacent sidecars, and embedded collections produce distinct availability evidence |
| Caller-provided DAT and repository/package extraction | Implemented | Local DAT, repository root/`Updates.xml`, explicit archive, and package-directory inputs are bounded and traversal-safe; no network fetching |
| Raw controller/component scripts | Implemented | Named RCC source is returned verbatim with role and bounded assignment-site values; JavaScript is never executed |
| Conditional JavaScript control flow | Partial | Raw expressions and assignment sites are preserved; branches and host APIs require agent or VM analysis |

## Known gaps

QtScript or JavaScript controller code may change target directory, scope, package selection, operation arguments, or runtime values conditionally. The parser returns the complete source and conservative assignment evidence, but it does not interpret general control flow or execute scripts. Performed-operation effects describe records already serialized into maintenance media and do not predict operations that an installer script might add only at runtime.

Separate package data cannot be recovered unless the caller supplies a local DAT, repository, or package archive. Remote repository URLs are evidence only and are never fetched by the parser. Encrypted package archives are identified by the archive reader but are not decrypted.

## Implementation mapping

- `Modules/InstallerParsers/Libraries/Installers/QtInstallerFrameworkFormatCatalog.psd1` defines profiles and capabilities.
- `Modules/InstallerParsers/Libraries/Installers/QtInstallerFramework.psm1` implements routes, metadata analysis, and extraction.
- `Modules/PackageModule/Libraries/Installers/QtInstallerFramework.psm1` is the Apache-2.0 process bridge.

## Representative fixtures

Catalog boundaries use official Qt IFW Windows installers for 1.3.0, 1.5.0, 2.0.5, 3.2.2, 4.0.0, and 4.2.0, plus the official Qt 4.11 online installer. Qt Linguist supplies a 3.0.6 GUI-only case. MSYS2, reMarkable, and Vulkan SDK cover distinct 4.x CLI and package-layout behavior. Synthetic fixtures cover 1.2-compatible records, future fallback, every marker/cookie pair, decoded operation effects, malformed indexes, and every Qt-supported package archive suffix.

## Source references

- [Qt Installer Framework source](https://github.com/qtproject/installer-framework)
- [UpdateOperation XML serialization](https://github.com/qtproject/installer-framework/blob/master/src/libs/kdtools/updateoperation.cpp)
- [Windows file-type registration operation](https://github.com/qtproject/installer-framework/blob/master/src/libs/installer/registerfiletypeoperation.cpp)
- [Package archive factory](https://github.com/qtproject/installer-framework/blob/master/src/libs/installer/archivefactory.cpp)
- [Maintenance-tool ARP registration](https://github.com/qtproject/installer-framework/blob/master/src/libs/installer/packagemanagercore_p.cpp)
- [Qt Installer Framework release archive](https://download.qt.io/archive/qt-installer-framework/)
- [Qt Installer Framework CLI](https://doc.qt.io/qtinstallerframework/ifw-cli.html)
