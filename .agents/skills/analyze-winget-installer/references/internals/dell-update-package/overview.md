# Dell Update Package internals

## Supported formats and variants

The supported outer runtime identifies itself as `DUPFramework.exe` in its version resource. Historical framework `003.000.000.000` packages use ZIP and MUP specification 2.1.0. Observed CommandUpdate 4.1.0 media also contains ZIP; CommandUpdate 5.7.2 and Universal 5.7.2 contain 7z. The physical archive and configured vendor technology are independent layers. MUP `packagingtype=executable` or `zip` does not select the outer archive decoder.

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

WinGet projection uses the exact selected family's defaults through passthrough, supplemented by WinGet's known-type defaults. It ignores embedded MUP arguments rather than merging their properties, transforms, wait flags, scope selectors or mode tokens into the preferred route. DUP's outer return codes remain applicable. InstallShield Basic MSI and InstallScript MSI wrap the selected database's directory property in `/V`; Advanced UI uses suite-level switches. Missing MSI directory evidence does not justify inventing a property. Unrecognized families, unusable defaults and unresolved extra execution layers retain the embedded-command route. An explicit caller override takes precedence over suggestions.

The `EmbeddedMup` suggested manifest variant preserves the original wrapper switches and modes separately, with the exact vendor command under `Evidence.VendorArguments`. If defaults fail VM validation, inspect the alternative for the affected package-specific option and adopt only what the failure evidence requires. Preserve the selected mode and forwarding syntax, reanalyze the changed command, and validate its installed state. The complete `/s` alternative remains available when partial adaptation cannot be established. Raw `CommandBehavior` and nested metadata continue to describe the analyzed command, not the defaults-only suggestion.

The delimiter belongs in every experience switch because WinGet appends logging before custom options and installation location last. Every appended option must reach the vendor after `/passthrough`; the normal outer `/l` option cannot be reused. This changes advisory manifest fields only. The physical records and raw parser metadata continue to describe the command actually analyzed, so callers must reanalyze authored overrides and validate their runtime behavior.

InstallShield accepts multiple attached `/V` operands, but each operand's literal quotes require backslash escaping: `/V"/log \"<LOGPATH>\""` and `/V"INSTALLDIR=\"<INSTALLPATH>\""`. The selected MSI supplies the actual directory property. Doubled nested quotes produced outer status `1` with no ARP, payload or vendor log in the CommandUpdate 4.1.0 VM test; escaped quotes succeeded with spaced paths. Separate `/v "..."` framing is invalid in the vendor contract. Embedded framing does not affect the independent defaults-only projection; manually adopted fallback options must follow the vendor syntax.

## Detection invariants

A valid PE, exact DUPFramework original filename, recognized archive at the overlay boundary and parsed Dell MUP namespace jointly establish the route. A filename containing Dell, an arbitrary archive with Mup.xml, and marker-only files do not qualify. XML roots, namespaces and executable multiplicity are validated without enabling external entities or DTDs.

## Metadata projection

`packageinformation` supplies application name/version, specification version, declared installer technology, release type, OS/architecture filters and content records. `inventorymetadata` can use MSI UpgradeCodes or Dell registry keys to detect installed versions. These records are not the package's visible uninstall-key definition. `package.xml` is a separate `SoftwareComponent` document; observed encodings include BOM-less UTF-16LE with an XML declaration, which must be decoded by an XML-aware byte reader rather than assumed to be UTF-8.

`SoftwareComponent` retains release/vendor versions, release date, package/release IDs, reboot hints, supported systems, supported devices, operating systems, descriptive requirements and localized revision history. Those release IDs and GUIDs stay wrapper metadata. PE file-version strings identify the framework build, while MUP version identifies the application; they must not overwrite each other.

Visible ARP fields come from the selected nested parser. An InstallShield wrapper supplies its Setup.ini-selected MSI metadata; Advanced UI instead supplies the suite's own ARP, even when several MSIs are present. A direct MSI uses the shared MSI reader. A single configured 7z SFX command can be followed through up to three additional wrapper layers. Incomplete nested parsing leaves ARP unresolved and preserves existing manifest values. Package name/version are not used as fallback uninstall display values.

The effective vendor command is part of the installed-state evidence, whether selected from MUP or supplied through `/passthrough`. NSIS receives it through the analyzer's virtual command-line input. For readers that do not simulate runtime overrides, assignments such as `ALLUSERS`, `MSIINSTALLPERUSER`, `ARPSYSTEMCOMPONENT`, `ProductCode`, `ProductName`, `ProductVersion`, `Manufacturer`, installation-directory properties and `TRANSFORMS` invalidate the affected default fields. The selected MSI's `InstallLocationProperty` or property name from `InstallLocationSwitch` identifies a package-specific directory override. Scope and directory changes invalidate dependent locations, uninstall commands, icons, protocols, extensions and association records; transforms additionally invalidate identity, UpgradeCode, visibility, registry view and ARP links. Raw nested facts remain available, but they cannot become authoritative wrapper ARP without evaluating that override. InstallShield prerequisite information remains separate from the selected MSI, and vendor success mappings remain separate from outer process codes.

Manifest authoring and updating pass effective authored `Silent` followed by `Custom` switches into analysis. Update cache keys include that command, so two entries sharing an installer file but using different passthrough arguments do not share installed-state results. The parser leaves passthrough unattended support unresolved rather than applying the default MUP switches or modes. The caller must validate the vendor command before authoring it.

Scope is nested evidence. A `requireAdministrator` outer manifest supports elevation but does not prove the resulting registry hive. MUP's unique supported architecture is OS applicability evidence; configured executable, outer PE and selected nested package architectures are kept separately. CommandUpdate Win32 is an example of an x64-targeted package carrying an x86 MSI. Universal instead uses an x64 MSI and also registers an x86 AppX package. Protocols and extensions are delegated to the selected parser, never inferred from inventory file lists or prerequisite contents.

## Bounds and malformed input

Each XML entry is limited to 4 MiB with DTDs disabled and no XML resolver. The outer catalog allows at most 16,384 file entries and defaults to a 4 GiB declared expanded-byte limit. Links, encryption, rooted/traversing paths and case-insensitive canonical path duplicates are rejected. The extractor also enforces actual expanded bytes, collision policy and configured entry limits. Bounded archive streams own no data outside their validated range.

Validate the certificate's complete range against the source length before using its offset as a logical payload end. Malformed core MUP records reject detection. Optional `package.xml` parse/root/size failures leave that metadata unresolved without rejecting a structurally proven executable route.

Additional 7z SFX stages share the remaining staging-byte budget and have a depth bound. Nested family parsers enforce their own format-specific limits. They never execute payloads. A selected payload parse failure becomes an incomplete diagnostic; an unsafe outer container is rejected before extraction.

An empty archive entry remains valid after previous entries consume the exact output budget. Its declared size must be zero, and its decompressed stream is checked for unexpected content. Nonempty entries and forged zero-length records still fail without extending the budget.

## Performance considerations

The wrapper reads PE layout/version evidence, catalog and each XML document once per direct analysis. Detection performs configuration analysis only. Full analysis retains one archive context; a directly selected MSI stages only that exact catalog entry, while EXE routes retain support-file relationships. Direct MSI staging does not use wildcard matching, which could also select a same-named file under another directory. The full physical catalog is validated in both cases, and public extraction still exports every requested wrapper entry. Nested InstallShield parsing reuses its selected MSI result. The shared 7z locator independently validates its candidate archive before the retained context is opened. Full 7z staging now uses SharpCompress's sequential solid-block reader rather than reopening each entry. The reader is used only for borrowed-stream archives whose ownership policy leaves the archive usable after reader disposal; selective and file-owned extraction retain direct access. Empty and collision-skipped files advance through the reader explicitly. Path, link, entry-count and aggregate-byte checks still apply before output. Full staging is needed for nested installers referencing external support files and is skipped with `SkipNestedAnalysis`.

The generic analyzer now keeps the validated Dell probe context through nested parsing instead of reopening the outer container. Ownership is operation-local: the analyzer releases all source/archive streams in `finally`, and no context enters public analysis evidence. `Test-DellUpdatePackage -PassThru` transfers ownership to independent callers; `Get-DellUpdatePackageInfo -AnalysisContext` borrows that context, checks its source and open state, and reapplies a smaller caller-specified expanded-byte budget. There is no process-wide file cache. Direct MSI selection skips the unrelated Dell-EXE probe.

A five-run warmed container-only comparison measured median separate-probe versus reused-probe time of 266/137 ms for CommandUpdate 4.1.0, 221/100 ms for 5.7.2, and 1173/576 ms for Optimizer ARM64. Median allocated memory was 13.3/8.5, 141.8/71.5 and 137.4/69.6 MiB respectively. Both paths returned the same package version and catalog count. These measurements exclude payload staging and nested parsing; the shared 7z locator's own validation and nested parser costs remain.

`Benchmark-InstallerParsers.ps1 -DellUpdatePackagePath` measures configuration-only parsing, nested analysis and WinGet analysis in fresh PowerShell processes. Module initialization is outside operation time; the report also records allocations and sampled process working set. Compare the same fixture and machine without concurrent parser workloads. Large solid suites remain a separate performance case from a small direct-MSI ZIP; selective MSI staging does not eliminate repeated probing or solid-block decoding.

An isolated Optimizer ARM64 staging comparison alternated direct-entry and sequential extraction twice. Both routes produced the same three file hashes. Direct extraction took 2.03/2.05 seconds and allocated 642/640 MiB; sequential extraction took 1.95/1.92 seconds and allocated 609/608 MiB. These local component measurements do not establish an end-to-end speedup: the full-analysis before/after reports varied while VM work overlapped, and nested suite parsing remains the larger cost. Keep the reports and hashes with the durable research evidence rather than imposing these timings as CI thresholds.

## Known gaps

Dell hardware applicability is not emulated. BIOS/firmware wrappers with different containers are not classified through vendor strings. The historical `SVMSEZ32.bin` wrapper in NVIDIA package X2XJJ is a distinct format: it lacks DUPFramework identity and was not located by the supported ZIP/7z probes. Supporting it requires a new container route, not another accepted original filename. Custom Intel launchers in CPNKY/GVCVP remain unresolved nested families. They can register ARP dynamically or delegate to external code. Those effects require focused static research or a suitable test system. A valid MUP inventory key never fills that gap automatically. Nested DUPs are not followed because they introduce another independent applicability layer. Optional package metadata may describe prerequisites in prose rather than executable configuration; it is retained as evidence without adding WinGet dependencies.

## Implementation mapping

`DellUpdatePackage.psm1` owns framework identity, MUP projection and nested-route composition. `PE.psm1` supplies raw-section/certificate/version evidence; `Archive.psm1` supplies ZIP/7z range discovery and bounded streaming; `FileSystem.psm1` supplies path/collision safety. Existing MSI, InstallShield and EXE parsers own installed-state facts. `InstallerAnalyzer` confirms the outer family before generic archive hints; `WinGetAnalysis` projects only schema-valid suggestions.

## Representative fixtures

CommandUpdate 4.1.0 exercises file-absolute ZIP offsets. CommandUpdate and Universal 5.7.2 exercise signed 7z media selecting distinct MSI identities, including a Universal mapping of vendor success to reboot-required. Optimizer 6.3.5.0 ARM64 exercises a large package and suite-owned identity across multiple MSI parcels. Synthetic tests cover ZIP-relative offsets, malformed XML, absent selection, traversal, collisions, duplicates, truncation, certificate overlap and limits. Binaries remain in the persistent fixture cache and are not redistributed with the tests.

Catalog-derived historical regressions include CPNKY 9.3.0.1019, NN71R 8.1.0 and GVCVP 15.7.0.0, all with framework 3.0 and MUP 2.1 ZIP media. NN71R selects `omcix64.msi`, whose ProductCode is `{D390C5DD-9312-4F70-B3B1-4EAE635CDA17}` and ProductName is `Dell OpenManage Client Instrumentation`. Its scope remains unresolved. CPNKY and GVCVP select lowercase `setup.exe` while their ZIP entries use `Setup.exe`; they cover the path-spelling regression and retain unknown vendor ARP. X2XJJ 265.70 and K0T3Y A08 are negative fixtures for the DUPFramework route. Downloaded files are checked against `SoftwareComponent.hashMD5`; provenance also records a computed SHA256. Model catalogs obtained through CatalogIndexPC and the PC catalog retain historical release paths even when current package pages no longer surface them.

VM evidence confirms the selected CommandUpdate uninstall keys for 4.1.0 and both 5.7.2 variants, together with names, versions, publishers, locations and machine scope. Win32 uses the 32-bit registry view; Universal uses the 64-bit view. Missing .NET Desktop 10 prevented both newer packages from registering any captured installed-state changes and returned outer status `4`. Installing runtime 10.0.12 allowed Win32 status `0` and Universal status `2`; no reboot was requested. The main MSI identity remains separate from the Dell Core Services prerequisite and Universal's AppX registration. Optimizer ARM64 installation has not been dynamically validated.

An additional CommandUpdate 4.1.0 probe used `/passthrough /clone_wait /s /v"/qn DUMPLINGS_PASSTHROUGH=1 /l*v \"<guest log path>\""`. The MSI log contained the property in its command line, property-change record and final property set, and the vendor log was created at the requested path. Outer install and MSI uninstall both returned `0`. The observed ProductCode, DisplayName, DisplayVersion, Publisher, scope and location matched static parsing; the after-cleanup comparison contained zero ARP, association and PATH changes. The probe did not restore or restart the shared VM.

The earlier split-switch projection was also tested in `silent` and `silentWithProgress` modes for all three CommandUpdate artifacts. All six runs created vendor logs and installed files into custom paths containing spaces. Their visible ARP identities, names, versions, publishers, scopes and registry views matched the parser; path-changing arguments correctly withheld the parser's default location. Win32 returned `0`, Universal returned `2`. Those tested commands retained embedded MUP arguments; defaults-only suggestions without those arguments require separate VM validation. The newer Win32 artifact without .NET Desktop 10 returned `4` with a vendor log and no main installation. The test removed its main packages, Dell Core Services and the runtime bundle it had added. The final comparison contained only independent Edge/WebView version updates; those unrelated changes were preserved.

Subsequent defaults-only runs on all three CommandUpdate artifacts passed both modes without `/clone_wait`, with identical main ARP tuples and outer exit codes. Each had ARP, payload files and the vendor log at wrapper exit. Adding only `ARPSYSTEMCOMPONENT=1` through an attached `/V` operand produced hidden MSI registration in both 4.1.0 modes; the command-aware outer projection withheld visible ARP fields rather than copying unmodified nested defaults. Explicit `ALLUSERS=1` runs also passed both modes with machine registration while the parser withheld its unsimulated scope default. Final cleanup removed the test-added packages, Core Services and runtime, leaving zero captured ARP, protocol, extension or PATH differences without restoring or restarting the shared VM.

NN71R's selected `omcix64.msi` completed both direct-MSI passthrough modes with outer `0`. VM registration matched ProductCode, DisplayName, DisplayVersion and Publisher, using machine scope and Registry64 for the tested commands. A first long-path run failed its `caOMILTestINSTALLDIR` custom action: the MSI requires an installation directory of at most 80 characters. A shorter spaced path worked without changing platform checks or copying MUP arguments. This custom-action policy is runtime evidence, not a general MSI or DUP path limit. Optimizer ARM64 remains unvalidated dynamically on the x64 guest.

## Source references

- [Dell DUP overview](https://www.dell.com/support/manuals/en-us/dell-update-packages/dup_framework_23.12.00_ug_pub/overview-of-dell-update-package?guid=guid-32ee9eb0-6a60-4ccd-abeb-4a31808c1cbb&lang=en-us).
- [Windows CLI options](https://www.dell.com/support/manuals/en-ca/dell-update-packages-v17.10.00/dup_17.10_users_guide/windows-cli-options?guid=guid-7e40f460-fdff-4cf9-b26f-e58065d8acbe&lang=en-us).
- [Dell Intel adapters guide](https://dl.dell.com/manuals/all-products/esuprt_ser_stor_net/esuprt_pedge_srvr_ethnt_nic/intel-pro-adapters_user%27s%20guide4_en-us.pdf), Windows command-line `/passthrough` contract and option conflicts.
- [DUP exit codes](https://www.dell.com/support/manuals/en-mq/dell-update-packages/dup_framework_24.08.00_ug_pub/exit-codes-for-cli?guid=guid-709bb23f-1f40-492f-8774-bbed273df825&lang=en-us).
- [Dell Update Packages user guide](https://dl.dell.com/topicspdf/dell-update-packages_users-guide_en-us.pdf).
- [Dell catalog reference guide](https://downloads.dell.com/manuals/all-products/esuprt_software/esuprt_ent_sys_mgmt/esuprt_catalog_manual/catalog_reference%20guide_en-us.pdf), catalog manifests and SoftwareComponent records.
- [InstallShield Setup.exe arguments](https://docs.revenera.com/installshield/helplibrary/IHelpSetup_EXECmdLine.htm), attached `/v` framing, repeated operands and embedded quote escaping.
- [SharpCompress SevenZipArchive](https://github.com/adamhathcock/sharpcompress/blob/0.39.0/src/SharpCompress/Archives/SevenZip/SevenZipArchive.cs), sequential folder streams; [AbstractReader](https://github.com/adamhathcock/sharpcompress/blob/0.39.0/src/SharpCompress/Readers/AbstractReader.cs), entry advancement and volume disposal.
- Embedded MUPDefinition and SoftwareComponent XML from the persistent fixtures; these are the artifact-specific execution and catalog witnesses.
