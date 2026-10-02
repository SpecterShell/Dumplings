# Dell Update Package internals

## Supported formats and variants

The supported outer runtime identifies itself as `DUPFramework.exe` in its version resource. Historical framework `003.000.000.000` packages use ZIP and MUP specification 2.1.0. Observed CommandUpdate 4.1.0 media also contains ZIP; CommandUpdate 5.7.2, Universal 5.7.2 and Watchdog Timer 2.0.0.1 contain 7z. The physical archive and configured vendor technology are independent layers. MUP `packagingtype=executable` or `zip` does not select the outer archive decoder.

This reference describes verified Windows DUP containers. Dell BIOS-specific executables, Linux packages and unrelated Dell-branded installer engines require their own structural evidence. No commercial framework release is inferred from the packaged application's version.

## Binary structure

```text
absolute file offsets
0                              DOS/PE image and section table
PE section raw ranges          .text/.rdata/.rsrc/etc.
max(RawOffset + RawSize)        overlay start
  +-- ZIP local headers or 7z signature header
  |   +-- Mup.xml
  |   +-- package.xml (optional)
  |   +-- configured executable
  |   `-- supporting entries
  `-- archive central/next header
optional observed tail bytes   reserved; no assigned semantics
Certificate.Offset             WIN_CERTIFICATE, when present after payload
```

The PE security directory uses a file offset, not an RVA. When its certificate range follows the section data, that offset bounds the payload's logical end. The archive must not cross it. Signing bytes and observed four-/seven-byte archive tails are not entry data.

### ZIP route

```text
record-relative  size    local file header (integers little-endian)
0x00               4    50 4B 03 04 (PK local-header magic)
0x04               2    extraction version
0x06               2    flags
0x08               2    compression method
0x0A               4    DOS time/date
0x0E               4    CRC32
0x12               4    compressed size (descriptor variants are possible)
0x16               4    expanded size
0x1A               2    filename byte length
0x1C               2    extra-field byte length
0x1E            variable filename, extra data, compressed entry bytes

central directory: 50 4B 01 02; end record: 50 4B 05 06
```

CommandUpdate 4.1.0 has a local header at the PE overlay start, but its central directory records include the PE stub in their offsets. Consequently, the resolved ZIP range starts at absolute offset zero. ZIP-relative variants resolve to the overlay instead. Derive the base from the end record and central-directory size/offset; do not subtract the stub twice. ZIP name encoding, extra fields, descriptor records and compression are handled by the shared archive implementation.

### 7z route

```text
archive-relative offset  size  signature header
0x00                       6  37 7A BC AF 27 1C
0x06                       1  major version
0x07                       1  minor version
0x08                       4  start-header CRC32, uint32 LE
0x0C                       8  next-header offset, uint64 LE
0x14                       8  next-header size, uint64 LE
0x1C                       4  next-header CRC32, uint32 LE
0x20                variable  packed streams
0x20 + next-header offset     next header, possibly encoded/compressed
```

The 7z archive starts exactly at the overlay boundary. Its bounded length is `32 + next-header offset + next-header size`. Validate the signature and range before opening it. Current fixtures use LZMA2 and can be solid; opening an entry near the end may decompress preceding entries in the same block. The parser streams through SharpCompress rather than buffering the entire installer or calling an external extractor.

## Payload selection and nested execution

`Mup.xml` is the execution contract. Its root is `MUPDefinition` in `http://schemas.dell.com/openmanage/cm/2/0/mupdefinition.xsd`. Exactly one `executable/executablename` identifies the vendor payload. The name is matched case-insensitively as an exact archive-relative path; all paths are checked for traversal and canonical duplicates. Open the matching catalog entry's actual filename spelling, including for an additional SFX layer. Windows command lookup is case-insensitive, but an NTFS staging directory can be case-sensitive. Absence of that payload is incomplete evidence, not permission to select another executable.

```text
outer DUP /s
  -> behaviors/behavior[@name='unattended']
  -> vendoroption arguments, including quoted containers
  -> selected executable
  -> its own configuration-selected MSI/EXE
  -> installed files, registry and ARP

outer DUP /passthrough <vendor arguments>
  -> replaces default MUP arguments with the verbatim tail
  -> same selected executable and physical payload
  -> vendor controls silent mode, logging and runtime overrides

vendor exit code
  -> MUP returncodemapping name
  -> outer DUP status (not necessarily the same integer)
```

`optionvalue` combines `switch`, literal text and optional value delimiter/quotes. A `container` adds its `containervalue` prefix and encloses its child arguments. For example, an InstallShield mapping can compose `/clone_wait /s /v/qn`; nested log mappings can add another quoted `/v` container. Required parameter values remain `<VALUE>` placeholders. The parser does not expand environment variables or run commands while interpreting these records.

Unsupported option elements retain their raw XML and unresolved reason. An unattended route is usable only when exactly one behavior resolves to a nonempty command without required-value placeholders. Duplicate behaviors do not select a first-wins command. Configured SFX child arguments precede the caller arguments; each proven selection remains in the execution chain even when the final executable is opaque.

The outer `/s`, `/l`, `/u`, `/e`, `/r`, `/f` and applicability behavior are documented by Dell. Supported MUP `unattended` behavior determines whether an artifact has a usable default vendor command; accepting `/s` in the framework is insufficient on its own. `/r` and `/f` are excluded from normal suggestions. Application install-path support varies by package.

`/passthrough` selects a separate command route. Dell forwards all text after the option to the vendor executable, replacing the normal MUP arguments rather than appending to them. Suppressing the outer UI does not make the vendor command silent. The outer `/l`, `/f`, and `/capabilities` options are incompatible; a vendor log option after the delimiter belongs to the vendor. The physical executable selection remains the MUP reference.

The analyzer accepts a virtual outer command line without running it. Windows-style tokenization identifies the standalone `/passthrough` option and records UTF-16 token extents. Taking the original substring after that extent preserves nested quotes and backslashes; rebuilding a string from decoded tokens would lose them. Text containing the option inside another token and `/passthrough-extra` are not delimiters. Later tokens, including another `/passthrough`, remain part of the vendor tail. `CommandBehavior` records the effective arguments, original MUP default, command source and incompatible prefix options. Unresolved replaced MUP behaviors stay in `Configuration` without creating an installability warning for the independent override.

WinGet projection prefers passthrough when the exact selected family offers additional command capabilities or different known mode switches. It combines that family's projection with WinGet's existing known-type defaults, retains configured properties, transforms, wait flags and scope options, and keeps DUP's outer return codes. InstallShield Basic MSI and InstallScript MSI wrap the selected database's directory property in `/V`; Advanced UI retains suite-level arguments. Missing MSI directory evidence does not justify inventing a property. Unrecognized families, unresolved extra execution layers and unsafe argument framing retain the embedded-command route. An explicit caller override takes precedence over either suggestion.

The delimiter belongs in every experience switch because WinGet appends logging before custom options and installation location last. Every appended option must reach the vendor after `/passthrough`; the normal outer `/l` option cannot be reused. This changes advisory manifest fields only. The physical records and raw parser metadata continue to describe the command actually analyzed, so callers must reanalyze authored overrides and validate their runtime behavior.

## Detection invariants

A valid PE, exact DUPFramework original filename, recognized archive at the overlay boundary and parsed Dell MUP namespace jointly establish the route. A filename containing Dell, an arbitrary archive with Mup.xml, and marker-only files do not qualify. XML roots, namespaces and executable multiplicity are validated without enabling external entities or DTDs.

## Metadata projection

`packageinformation` supplies application name/version, specification version, declared installer technology, release type, OS/architecture filters and content records. `inventorymetadata` can use MSI UpgradeCodes or Dell registry keys to detect installed versions. These records are not the package's visible uninstall-key definition. `package.xml` is a separate `SoftwareComponent` document; observed encodings include BOM-less UTF-16LE with an XML declaration, which must be decoded by an XML-aware byte reader rather than assumed to be UTF-8.

`SoftwareComponent` retains release/vendor versions, release date, package/release IDs, reboot hints, supported systems, supported devices, operating systems, descriptive requirements and localized revision history. Those release IDs and GUIDs stay wrapper metadata. PE file-version strings identify the framework build, while MUP version identifies the application; they must not overwrite each other.

Visible ARP fields come from the selected nested parser. An InstallShield wrapper supplies its Setup.ini-selected MSI metadata; Advanced UI instead supplies the suite's own ARP, even when several MSIs are present. A direct MSI uses the shared MSI reader. A single configured 7z SFX command can be followed through up to three additional wrapper layers. The selected custom launcher may still be opaque, as in Watchdog media. Incomplete nested parsing leaves ARP unresolved and preserves existing manifest values. Package name/version are not used as fallback uninstall display values.

The effective vendor command is part of the installed-state evidence, whether selected from MUP or supplied through `/passthrough`. NSIS receives it through the analyzer's virtual command-line input. For readers that do not simulate runtime overrides, assignments such as `ALLUSERS`, `MSIINSTALLPERUSER`, `ARPSYSTEMCOMPONENT`, `ProductCode`, `ProductName`, `ProductVersion`, `Manufacturer`, installation-directory properties and `TRANSFORMS` invalidate the affected default fields. Raw nested facts remain available, but they cannot become authoritative wrapper ARP without evaluating that override. InstallShield prerequisite information remains separate from the selected MSI, and vendor success mappings remain separate from outer process codes.

Manifest authoring and updating pass effective authored `Silent` followed by `Custom` switches into analysis. Update cache keys include that command, so two entries sharing an installer file but using different passthrough arguments do not share installed-state results. The parser leaves passthrough unattended support unresolved rather than applying the default MUP switches or modes. The caller must validate the vendor command before authoring it.

Scope is nested evidence. A `requireAdministrator` outer manifest supports elevation but does not prove the resulting registry hive. MUP's unique supported architecture is OS applicability evidence; configured executable, outer PE and selected nested package architectures are kept separately. CommandUpdate Win32 is an example of an x64-targeted package carrying an x86 MSI. Universal instead uses an x64 MSI and also registers an x86 AppX package. Protocols and extensions are delegated to the selected parser, never inferred from inventory file lists or prerequisite contents.

### Watchdog's custom execution layer

```text
DUPFramework + Mup.xml
  -> WDTSetup_MUP.exe: configured 7z SFX
    -> WDTAppSetUp.exe: Foxconn native launcher
      +-- setup.exe: InstallShield InstallScript runtime
      |   +-- setup.ini / setup.inx
      |   +-- data1.hdr / data1.cab / data2.cab / ISSetup.dll
      |   `-- setup.iss / uninstall.iss
      `-- Drivers/Windows10-x64: INF, SYS and CAT
```

This is an execution graph, not physical byte adjacency. The SFX contains the custom launcher and adjacent InstallShield media. WDTAppSetUp builds a local `setup.exe` path, handles separate driver and maintenance paths, and invokes child processes through `CreateProcessA`. Its launch helper waits with `WaitForSingleObject`; the helper's returned wait status is not a child process exit code. Static strings include `/s`, driver extraction and driver-only arguments, while the maintenance path names the InstallShield Installation Information directory. Those observations confirm a custom translation layer, not automatic forwarding of every caller argument.

The supplied InstallShield response files identify their dialog responses and product configuration. They do not prove that every wrapper command reaches that installer, that the driver succeeds on unrelated hardware, or that the wrapper's final exit code equals InstallShield's. The `setup.ini` ProductGUID is therefore candidate evidence until the visible uninstall key is established through the actual command route. The current nested parser deliberately stops at the unsupported Foxconn launcher rather than choosing a neighboring `setup.exe` by filename.

## Bounds and malformed input

Each XML entry is limited to 4 MiB with DTDs disabled and no XML resolver. The outer catalog allows at most 16,384 file entries and defaults to a 4 GiB declared expanded-byte limit. Links, encryption, rooted/traversing paths and case-insensitive canonical path duplicates are rejected. The extractor also enforces actual expanded bytes, collision policy and configured entry limits. Bounded archive streams own no data outside their validated range.

Validate the certificate's complete range against the source length before using its offset as a logical payload end. Malformed core MUP records reject detection. Optional `package.xml` parse/root/size failures leave that metadata unresolved without rejecting a structurally proven executable route.

Additional 7z SFX stages share the remaining staging-byte budget and have a depth bound. Nested family parsers enforce their own format-specific limits. They never execute payloads. A selected payload parse failure becomes an incomplete diagnostic; an unsafe outer container is rejected before extraction.

## Performance considerations

The wrapper reads PE layout/version evidence, catalog and each XML document once per direct analysis. Detection performs configuration analysis only. Full analysis retains one archive context; a directly selected MSI stages only that exact catalog entry, while EXE routes retain support-file relationships. Direct MSI staging does not use wildcard matching, which could also select a same-named file under another directory. The full physical catalog is validated in both cases, and public extraction still exports every requested wrapper entry. Nested InstallShield parsing reuses its selected MSI result. The shared 7z locator independently validates its candidate archive before the retained context is opened. Solid archives can require repeated block decoding; benchmark large packages before changing entry order or extracting more files. Full staging is needed for nested installers referencing external support files and is skipped with `SkipNestedAnalysis`.

`Benchmark-InstallerParsers.ps1 -DellUpdatePackagePath` measures configuration-only parsing, nested analysis and WinGet analysis in fresh PowerShell processes. Module initialization is outside operation time; the report also records allocations and sampled process working set. Compare the same fixture and machine without concurrent parser workloads. Large solid suites remain a separate performance case from a small direct-MSI ZIP; selective MSI staging does not eliminate repeated probing or solid-block decoding.

## Known gaps

Dell hardware applicability is not emulated. BIOS/firmware wrappers with different containers are not classified through vendor strings. The historical `SVMSEZ32.bin` wrapper in NVIDIA package X2XJJ is a distinct format: it lacks DUPFramework identity and was not located by the supported ZIP/7z probes. Supporting it requires a new container route, not another accepted original filename. Custom Intel launchers in CPNKY/GVCVP and Foxconn's Watchdog launcher remain unresolved nested families. They can register ARP dynamically or delegate to external code. Those effects require focused static research or a suitable test system. A valid MUP inventory key never fills that gap automatically. Nested DUPs are not followed because they introduce another independent applicability layer. Optional package metadata may describe prerequisites in prose rather than executable configuration; it is retained as evidence without adding WinGet dependencies.

## Implementation mapping

`DellUpdatePackage.psm1` owns framework identity, MUP projection and nested-route composition. `PE.psm1` supplies raw-section/certificate/version evidence; `Archive.psm1` supplies ZIP/7z range discovery and bounded streaming; `FileSystem.psm1` supplies path/collision safety. Existing MSI, InstallShield and EXE parsers own installed-state facts. `InstallerAnalyzer` confirms the outer family before generic archive hints; `WinGetAnalysis` projects only schema-valid suggestions.

## Representative fixtures

CommandUpdate 4.1.0 exercises file-absolute ZIP offsets. CommandUpdate and Universal 5.7.2 exercise signed 7z media selecting distinct MSI identities, including a Universal mapping of vendor success to reboot-required. Optimizer 6.3.5.0 ARM64 exercises a large package and suite-owned identity across multiple MSI parcels. Watchdog Timer 2.0.0.1 exercises driver inventory, an extra configured 7z wrapper and unresolved custom-launcher ARP. Synthetic tests cover ZIP-relative offsets, malformed XML, absent selection, traversal, collisions, duplicates, truncation, certificate overlap and limits. Binaries remain in the persistent fixture cache and are not redistributed with the tests.

Catalog-derived historical regressions include CPNKY 9.3.0.1019, NN71R 8.1.0 and GVCVP 15.7.0.0, all with framework 3.0 and MUP 2.1 ZIP media. NN71R selects `omcix64.msi`, whose ProductCode is `{D390C5DD-9312-4F70-B3B1-4EAE635CDA17}` and ProductName is `Dell OpenManage Client Instrumentation`. Its scope remains unresolved. CPNKY and GVCVP select lowercase `setup.exe` while their ZIP entries use `Setup.exe`; they cover the path-spelling regression and retain unknown vendor ARP. X2XJJ 265.70 and K0T3Y A08 are negative fixtures for the DUPFramework route. Downloaded files are checked against `SoftwareComponent.hashMD5`; provenance also records a computed SHA256. Model catalogs obtained through CatalogIndexPC and the PC catalog retain historical release paths even when current package pages no longer surface them.

VM evidence confirms the selected CommandUpdate uninstall keys for 4.1.0 and both 5.7.2 variants, together with names, versions, publishers, locations and machine scope. Win32 uses the 32-bit registry view; Universal uses the 64-bit view. Missing .NET Desktop 10 prevented both newer packages from registering any captured installed-state changes and returned outer status `4`. Installing runtime 10.0.12 allowed Win32 status `0` and Universal status `2`; no reboot was requested. The main MSI identity remains separate from the Dell Core Services prerequisite and Universal's AppX registration. Optimizer ARM64 and Watchdog driver installation have not been dynamically validated.

An additional CommandUpdate 4.1.0 probe used `/passthrough /clone_wait /s /v"/qn DUMPLINGS_PASSTHROUGH=1 /l*v \"<guest log path>\""`. The MSI log contained the property in its command line, property-change record and final property set, and the vendor log was created at the requested path. Outer install and MSI uninstall both returned `0`. The observed ProductCode, DisplayName, DisplayVersion, Publisher, scope and location matched static parsing; the after-cleanup comparison contained zero ARP, association and PATH changes. The probe did not restore or restart the shared VM.

## Source references

- [Dell DUP overview](https://www.dell.com/support/manuals/en-us/dell-update-packages/dup_framework_23.12.00_ug_pub/overview-of-dell-update-package?guid=guid-32ee9eb0-6a60-4ccd-abeb-4a31808c1cbb&lang=en-us).
- [Windows CLI options](https://www.dell.com/support/manuals/en-ca/dell-update-packages-v17.10.00/dup_17.10_users_guide/windows-cli-options?guid=guid-7e40f460-fdff-4cf9-b26f-e58065d8acbe&lang=en-us).
- [Dell Intel adapters guide](https://dl.dell.com/manuals/all-products/esuprt_ser_stor_net/esuprt_pedge_srvr_ethnt_nic/intel-pro-adapters_user%27s%20guide4_en-us.pdf), Windows command-line `/passthrough` contract and option conflicts.
- [DUP exit codes](https://www.dell.com/support/manuals/en-mq/dell-update-packages/dup_framework_24.08.00_ug_pub/exit-codes-for-cli?guid=guid-709bb23f-1f40-492f-8774-bbed273df825&lang=en-us).
- [Dell Update Packages user guide](https://dl.dell.com/topicspdf/dell-update-packages_users-guide_en-us.pdf).
- [Dell catalog reference guide](https://downloads.dell.com/manuals/all-products/esuprt_software/esuprt_ent_sys_mgmt/esuprt_catalog_manual/catalog_reference%20guide_en-us.pdf), catalog manifests and SoftwareComponent records.
- Embedded MUPDefinition and SoftwareComponent XML from the persistent fixtures; these are the artifact-specific execution and catalog witnesses.
