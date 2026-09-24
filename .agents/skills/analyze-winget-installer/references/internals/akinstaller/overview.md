# AKInstaller internals

This reference records the AKInstaller and AKInstallerMSI structures consumed by Dumplings. Use the [AKInstaller workflow](../../families/akinstaller/workflow.md) for WinGet authoring and VM validation.

## Supported formats and variants

AKApplications ships two related products with different runtime architectures. AKInstaller is a native setup compiler whose project table and payload archive are interpreted by custom runtime DLLs. AKInstallerMSI builds MSI databases and can wrap them with a prerequisite bootstrapper. Shared branding is not a shared binary format, so the parser dispatches each physical route independently.

The implemented parser is grounded in 2005-2006 AKPatch, IncCopy, and Update-Download-Tool product media; AKInstaller 4.4.505, 4.5.750, and 6.6.225; AKInstallerMSI 3.4.326, 3.5.1, 3.5.200, 5.5.700, 5.6.651, and 5.6.700 media; current official command-line documentation; and regify production installers. The classic native route uses consecutive GZip members and a compact catalog. Later native releases share the table record grammar but use different string transforms and protected-ZIP footer identities. Historical AKInstallerMSI media changes the ZIP central-directory signature while retaining the footer and protected-password grammar. Other versions remain accepted only when they satisfy a known bounded route; the parser does not infer an exact builder version from a packaged application's PE version.

Archived products provide the following structural catalog. Product version and builder version remain separate because most shipped native installers do not retain an authoritative builder release.

| Observed media | Route | Structural evidence |
| --- | --- | --- |
| Update-Download-Tool 1.7, AKPatch Standard 1.1.100, and IncCopy 3.0 | `AKInstaller/NativeClassicGZip` | six-word KAPI footer, consecutive GZip members, variable-width member catalog, table version 3, engine value 20, legacy XOR strings, and fixed-width classic file sizes |
| AKInstaller 4.4.505 and 4.5.750 | `AKInstaller/NativeLegacy` | protected ZIP, KAPI footer, table version 3, engine value 20, and legacy XOR strings |
| AKInstaller 6.6.225 | `AKInstaller/Native` | protected ZIP, AKINST footer, table version 3, engine value 20, and RC4 strings |
| AKPackIt 1.8.6 / AKInstallerMSI 3.4.326, AKInstallerMSI 3.5.1, and 3.5.200 | `AKInstallerMSI/BootstrapperLegacy` | INSTALLMSI footer, protected password, and `AKI\x02` central-directory records |
| AKInstallerMSI 5.4-5.6 production media | `AKInstallerMSI/Bootstrapper` | INSTALLMSI footer, protected password, standard ZIP central directory, `Config.ini_`, and one or more indexed payload sections |
| regipay 5.0 | `AKInstallerMSI/EmbeddedMsi` | bounded CFB database whose Summary Information identifies AKInstallerMSI |

The vendor's old-version page names additional releases, but release labels alone do not establish another binary layout. Archived AKPackIt from 2007 is a plain MSI and GLL demo downloads are ordinary product executables, so both correctly bypass this parser. Current MPIC Studio uses a distinct `MPIC EntpackerSetup` runtime and is retained as a negative vendor-branding case. Current Update-Download-Tool 2.9.610 validates the AKInstallerMSI 5.6.651 route.

## Classic native container

```text
setup.exe
+-- PE image                                      ImageEnd
+-- loader data                                   LoaderLength
`-- overlay
    +-- GZip member 1                             PayloadOffset
    +-- GZip member 2
    +-- ...
    +-- GZip member N
    +-- member count                              UInt32LE
    +-- member descriptors                        variable width
    |   +-- kind                                  UInt8, observed 4 or 6
    |   +-- identifier                            kind bytes
    |   `-- compressed size                       UInt32LE
    +-- observed/reserved                         UInt32LE
    +-- PE image end                              UInt32LE
    +-- loader-data length                        UInt32LE
    +-- observed flags                            UInt32LE
    +-- payload offset                            UInt32LE
    +-- observed checksum/value                   UInt32LE
    `-- >KAPI_SETUP<                              12 ASCII bytes
```

The footer does not store a catalog pointer. Dumplings searches only the bounded range before the footer for one catalog whose count and variable-width descriptors consume the complete catalog range and whose compressed sizes consume every byte from `PayloadOffset` to that catalog. Every member must begin with a valid GZip method-8 header, remain within the declared range, and expose a bounded ISIZE trailer. Kind 4 carries a four-byte identifier used to derive archive keys such as `A6e`; kind 6 carries six identifier bytes and is preserved under a stable hexadecimal key. The parser accepts the route only when one expanded member contains a valid `STPSETUPVERSION` project table with a decoded product identity.

## Native container

```text
setup.exe
+-- DOS and PE headers
+-- runtime sections and resources
`-- overlay
    +-------------------------------+ ArchiveOffset
    | ZipCrypto ZIP                 | ArchiveLength
    | A01 project table             |
    | A02 uninstall subset          |
    | A04 setup executable          |
    | A09/A11/A12 runtime DLLs      |
    | Axx application payloads      |
    +-------------------------------+
    | protected configuration       | ConfigLength bytes, each XOR A9
    +-------------------------------+
    | ConfigLength                  | UInt32LE
    | Runtime/component offset      | UInt32LE
    | ArchiveOffset                 | UInt32LE
    | ArchiveLength                 | UInt32LE
    | Flags                         | UInt32LE, observed
    | Reserved/observed             | UInt32LE
    | Reserved/observed             | UInt32LE
    +-------------------------------+
    | >AKINST_SETUP<                | 14 ASCII bytes, modern route
    | or >KAPI_SETUP<               | 12 ASCII bytes, legacy route
    +-------------------------------+
    | optional Authenticode table   |
    +-------------------------------+
```

The protected configuration is pipe-delimited. The second observed field is the ZIP password. It is retained only in the private analysis context and is never returned, logged, or written to extraction metadata. Footer validation requires the archive range to end before the protected configuration and requires the decrypted archive catalog to contain A01 and A11. The modern marker selects the `ModernRc4` table profile; the legacy marker selects `LegacyXor`. Marker selection is structural and is not replaced by a builder-version guess.

## A01 project table

```text
Offset  Size      Field
------  --------  ----------------------------------------------
0x00    15        ASCII STPSETUPVERSION
0x0F    1         table format version
0x10    4         engine/project value, UInt32LE
0x14    variable  named typed records
```

A named record begins with an ASCII `STP...` key followed immediately by a one-byte type and a four-byte little-endian field. In the modern profile, types 1 and 2 contain an RC4-encrypted UTF-16LE or byte string whose ciphertext length is the field, followed by one trailer byte. In the legacy profile, type 1 is a Windows-1252 byte string XORed with `0x7B`; type 2 receives the runtime's additional XOR `0x15` and therefore decodes with net XOR `0x6E`. Types 3 and 4 store the integer directly in the field. Type 5 contains an unencrypted byte string plus a trailer. Type 6 contains `field` little-endian UInt32 values plus a trailer. The trailer is framing, but verified media does not establish that it must contain zero.

A01 interleaves typed records with fixed-layout tables, so parsing cannot advance one cursor from offset `0x14` to the end. Dumplings finds bounded `STP...` candidates, validates the following typed cell, rejects candidates inside an already consumed record range, tracks duplicate names, and reports malformed candidates. Record-family projections retain their complete raw field dictionaries so future field mappings do not require rescanning or reparsing the archive.

The modern runtime derives the string cipher through CryptoAPI using MD5 and RC4. Its fixed password is hashed with the same byte-count behavior as the runtime's `lstrlenW` call. Dumplings stores only the resulting 16-byte RC4 key and independently implements the standard RC4 state permutation. The legacy runtime's exported table reader applies its two constant XOR passes. Decrypted field values are returned; the archive password is not.

Observed identity records include:

| Record | Meaning |
| --- | --- |
| `STPLAA01A` | application display name |
| `STPLAA02A` | registry/product name |
| `STPLAAX4V` | product GUID used by the default uninstall key |
| `STPLAA03A` | product version |
| `STPLAA04A` | manufacturer/publisher |
| `STPLAA05A` | descriptive setup title |
| `STPLAA06A` | default installation path expression |
| `STPLAA67A` | primary executable name |

`ProductVersion` comes from `STPLAA03A`. `CompiledPublisher` comes from `STPLAA04A`. `DisplayName`, `DisplayVersion`, and `Publisher` are ARP properties and remain null when the selected visible uninstall entry omits them; they never fall back to compiled package identity. These values can differ: archived Update-Download-Tool media packages version `1.9.10` but writes ARP DisplayVersion `1.7` and no Publisher. `Read-ProductVersionFromAKInstaller` returns the compiled or nested-MSI product version, not the ARP-only value.

Classic VM evidence distinguishes the two name fields: `STPLAA01A` supplies `<PRODUCTNAME>` and therefore the default installation-directory leaf, while `STPLAA02A` supplies `<REGPRODUCTNAME>` and the uninstall-key identity. Update-Download-Tool consequently installs under `Update-Download-Tool` but registers ProductCode `UDTMaker`. IncCopy uses the same string for both fields. The classic runtime appends a trailing separator inside its quoted `AKDeInstall.exe "/<INSTALLDIR>\"` argument even though `<INSTALLDIR>` itself is normalized without one; this behavior is specific to the uninstaller command and must not add an extra separator to other resolved paths.

## Native file rows

`STPLB<n>BBBB` describes a temporary support file and `STPLC<n>BBBB` describes an installed file. Later tables place four anonymous typed strings and one raw UInt32LE size after the key:

```text
+----------------------+ key end
| typed logical name   |
+----------------------+
| typed archive key    | Axx
+----------------------+
| typed destination    | may contain project variables
+----------------------+
| typed condition      |
+----------------------+
| expanded size        | UInt32LE, not a typed cell
+----------------------+
```

The parser stops typed-cell decoding before the raw size field. Default extraction includes STPLC rows and preserves paths relative to `<INSTALLDIR>`. STPLB rows are returned as temporary support evidence and are available through raw extraction. Metadata analysis and extraction use the same deterministic variable map, including Program Files, Common Files, Windows, system, temporary, application-data, installation-root, and scope-dependent shell-folder aliases. Conditions are preserved verbatim when they cannot be resolved safely.

The verified classic table stores logical name, archive key, and destination as three typed cells, followed immediately by a raw UInt32LE expanded size and then version-dependent option bytes. No condition cell is present. The matching GZip trailer supplies an independent physical size. Dumplings reads the size from its fixed position and uses the physical member descriptor for bounded extraction; it never treats a low size byte in the range 1 through 6 as a typed-cell tag. This distinction is selected by the validated classic route rather than by accepting a truncated later record. The option bytes remain raw until controlled projects establish their semantics.

## Native registry rows

Registry operations are grouped as `STPLD<n>C<field>C`. Field `01` is the key plus value-name path, field `02` is the value, and field `04` begins with source-backed bytes for registry type, create, remove on uninstall, only if missing, ignore errors, and trailing-slash policy. Remaining flag bytes and field `06` are retained without invented semantics. Literal roots include full hive names and observed numeric root tokens. The parser resolves only mapped tokens and skips unknown roots.

The default uninstall rows target `Software\Microsoft\Windows\CurrentVersion\Uninstall\<PRODUCTCODE>` and can contain `DisplayName`, `DisplayVersion`, `Publisher`, `InstallLocation`, `UninstallString`, `QuietUninstallString`, `DisplayIcon`, `HelpLink`, `URLInfoAbout`, `URLUpdateInfo`, and `EstimatedSize`. Custom uninstall-key names are legal. Dumplings groups rows by hive, registry view, and complete key path, requires a non-empty DisplayName for a visible entry, honors `SystemComponent`, returns hidden evidence separately, and selects the compiled product GUID only when it identifies a visible key. These rows are stronger ARP evidence than PE version resources. The same registry stream can define file-extension and protocol associations through HKCR or `Software\Classes` routes.

Deterministic variables include `<PRODUCTNAME>`, `<REGPRODUCTNAME>`, `<PRODUCTVERSION>`, `<MANUFACTURER>`, `<PRODUCTCODE>`, `<PROGRAMDIR>`, `<COMMONFILES>`, `<WINDOWS>`, `<SYSTEM>`, `<TEMPDIR>`, `<APPDATA>`, `<LOCALAPPDATA>`, `<COMMONAPPDATA>`, `<INSTALLDIR>`, and scope-specific start-menu, startup, and desktop roots. Runtime-derived variables remain unresolved. The parser uses manifest-safe environment syntax and does not evaluate DLL or script results.

## Native operation records

The builder project model and compiled fixtures establish these operation families. Dumplings returns the named properties while retaining `RawFields` for every row:

| Family | Projected evidence |
| --- | --- |
| `STPLF<n>E..E` | shortcuts: name, destination directory, arguments, working directory, description, target, icon, hotkey, and condition |
| `STPLG<n>F..F` | INI writes: path, section, key, value, flags, and condition |
| `STPLI<n>G..G` | prerequisite/custom execution: path, arguments, working directory, display name, accepted return-code text, detection property, condition, and detection expression |
| `STPLV<n>...` | launch condition, localized message key/text, and abort policy |
| `STPLX<n>B24.` | target path, principal, domain, access mask, and permission flags |
| `STPLS<n>B..B` | directory path and Win32 `FileAttributes` mask |
| `STPLW<n>I..H` | compiled property name, value, type code, and condition |
| `STPEX<n>EXA.` | extension identifier, extension-DLL archive key, optional data archive key, and display text |
| `STPLKNXN<n>` | file-operation applicability, operation, phase, source, destination, and condition |

`STPLKNXN` values use a three-character routing header followed by pipe-delimited arguments:

```text
+--------+--------+--------+----------------+---+----------------+---+----------------+
| target | opcode | phase  | source         | | | destination    | | | condition      |
+--------+--------+--------+----------------+---+----------------+---+----------------+
     1        1        1       variable          variable             variable bytes
```

The target character is `0` for setup and update, `1` for setup only, or `2` for update only. Runtime dispatch and builder serialization establish these operation characters: `D` DeleteFile, `R` Rename, `C` CopyFile, `M` MakeDir, `-` DeleteWildCard, `+` CopyWildCard, `!` RemoveDirIfEmpty, `F` MoveFile, and `X` CopyMultiWildCard. The phase character is `V` before installation, `N` after installation, `R` during rollback, `U` before uninstallation, or `X` after uninstallation. A command can omit its destination by leaving the second field empty. Dumplings resolves deterministic path variables, preserves conditions, and reports unknown codes or incomplete tuples without attempting the operation.

`STPLS` masks use the Windows file-attribute values directly; observed values include `0x00000002` for Hidden and `0x00000080` for Normal. `STPLW` corresponds to builder properties, which may hold a literal value or a condition-derived value. `STPEX` records point to native extension DLLs and optional extension data by archive key. The parser exposes those descriptors and never loads the DLL. Exported extension callbacks can run during preparation, execution, rollback, commit, and uninstallation, so their system effects remain a static-analysis or VM-validation boundary.

Conditions can reference runtime properties such as `UserPrivileged`, `VersionNT`, detected dependency versions, feature state, installed-product state, or custom properties. Verified media contains expressions such as `UserPrivileged >= 2`, `VersionNT >= 601`, and `IsInstalled AND ProductPreVersion $< "6.0"`. The parser preserves these expressions and reports runtime evaluation requirements because evaluating them against the analysis host would substitute the wrong installation context. Literal file and registry evidence remains available to an agent even when its applicability is conditional.

## AKInstallerMSI bootstrapper

```text
setup.exe
+-- PE runtime
`-- overlay
    +-------------------------------+ ZIP start derived from EOCD
    | ZipCrypto ZIP                 |
    | Config.ini_                   |
    | File1<logical-name>_          |
    | File2<logical-name>_          |
    | runtime helpers and UI files  |
    +-------------------------------+
    | password bytes XOR 54         | PasswordLength
    | secondary bytes XOR C6        | SecondaryLength
    +-------------------------------+
    | PasswordLength XOR 44         | UInt32LE
    | SecondaryLength XOR B2        | UInt32LE
    | flags/observed                 | UInt32LE
    | flags/observed                 | UInt32LE
    +-------------------------------+
    | >INSTALLMSI_SETUP<            | 18 ASCII bytes
    +-------------------------------+
```

The parser derives candidate ZIP starts from validated end-of-central-directory records, opens each candidate with the protected password, and accepts a range only when it contains `Config.ini_` and at least one configured MSI payload. Entry names retain a physical `FileN` prefix and trailing underscore. Logical extraction uses the corresponding `FileN.Path` value.

AKInstallerMSI 3.5.1 keeps standard local headers and EOCD data but replaces each central-directory signature `50 4B 01 02` (`PK\x01\x02`) with `41 4B 49 02` (`AKI\x02`). The EOCD still provides the archive start, central offset, size, and entry count. Dumplings validates every bounded central record, copies only the exact archive range to a temporary file, restores those signatures, and opens the temporary archive through the shared bounded archive path. A mismatched count, variable-length record boundary, or incomplete central range rejects the route.

`Config.ini` contains Main identity, supported languages, launch conditions, prerequisite checks, file groups, payload execution parameters, and path variables. A file section with an MSI path is extracted to a bounded temporary location and parsed by `Get-MsiInstallerInfo`. Dumplings returns indexed launch conditions and each file's conditions, detection tests, install/start mode, reboot policy, cancel/failure policy, accepted return-code text, and parameters. The configured ProductCode, explicit `Start=2`, or a sole nested MSI selects the primary MSI; a multi-MSI wrapper without one of those selectors is rejected instead of inheriting the first MSI. All parseable MSI payloads remain in `NestedInstallers`. An HTTP or HTTPS file path with no embedded entry is returned as an external prerequisite rather than reported as a corrupt archive; other configured-but-missing files remain incomplete evidence.

## Direct embedded MSI route

Some AKInstallerMSI output appends a CFB MSI database without the bootstrapper footer. A CFB magic match is only a candidate. Dumplings copies the bounded range to a temporary MSI, parses it, and accepts the route only when Summary Information `CreatingApp` matches `AKInstallerMSI`. The creating-application value can also supply the builder version, such as `AKInstallerMSI V5.5.700`.

## Bounds and extraction behavior

The parser caps the native project table at 16 MiB, archive catalogs at 65,536 entries, and public extraction at 4 GiB by default. Callers can set lower entry and byte limits. Every selected logical entry is matched to an existing physical archive record and the complete selection is preflighted before output begins, so a missing record or exceeded limit does not leave a partial extraction tree. Direct embedded-MSI extraction applies the same caller-supplied expanded-byte limit before copying its bounded CFB range.

Installed-file extraction uses logical STPLC destinations. Each projected payload records `DeclaredLength`, `PhysicalLength`, and whether those values agree; the physical archive length controls bounded extraction, and a disagreement produces `AKInstaller.Payload.SizeMismatch`. Wrapper extraction uses `FileN.Path` from `Config.ini`; raw extraction places physical names below `_akinstaller`. The common safe-target resolver rejects rooted paths, parent traversal, archive links, and destination escapes and applies the requested collision policy only after a real collision is found. Recovered ZipCrypto passwords remain private parser-context state and do not appear in public results or diagnostics.

## Command-line behavior

Protected-ZIP native AKInstaller `/silent 1` disables user interaction and automatically answers message boxes. `/NoReboot` or `/rn` prevents reboot and changes the reboot outcome from 1641 to 3010. The runtime does not provide a distinct progress-displaying unattended command, so the WinGet projection duplicates `/silent 1 /NoReboot` into `Silent` and `SilentWithProgress` while retaining only `interactive` and `silent` in `InstallModes`. `/installdir` selects the first-install destination. `/eula` accepts the license page and should be authored only when required by the compiled project. Uppercase public properties can override installation and data paths on supported versions. The classic 2.x-generation runtime contains an internal silent-state symbol but the verified artifacts do not expose enough structured command-line vocabulary to prove the later syntax. IncCopy 3.0, Update-Download-Tool 1.9.10, and AKPatch Standard 1.1.100 timed out on Windows 11 with both `/silent 1 /NoReboot` and generic `/S`; each route left its extracted `AKSetup.exe` child running and wrote neither ARP nor installed-file state. Exact classic analysis therefore returns interactive-only guidance and a manual-validation diagnostic.

The PE execution manifest is independent evidence. `requireAdministrator` maps to WinGet `elevationRequired`, which asks WinGet to launch the process elevated. Machine-scope ARP rows do not prove `elevatesSelf`; an `asInvoker` machine-scope artifact remains unresolved until runtime relaunch behavior is established.

AKInstallerMSI `/silent 2` suppresses bootstrapper message boxes. `/msilimitui 67` combines basic UI, disabled cancel, and progress-only flags for the product MSI. `/msiparam` forwards MSI properties and substitutes `@` for `/`; `/replaceparam` replaces rather than appends configured parameters. Although that substitution can express native MSI switches, a production 5.6 wrapper forwarded `@norestart` into an invalid nested command line and returned 1639. `REBOOT=ReallySuppress` is the VM-validated reboot-suppression form. `/logfile` writes a bootstrapper-selected MSI log under the temporary directory. Documented outcomes include 0, 1602, 1603, 1618, 1625, 1638, 3010, and 1641. WinGet projection omits 0 because it is the default success code and omits 1603 because the vendor assigns that generic failure to both disk-space and network failures; the six actionable outcomes receive their corresponding schema `ReturnResponse` values. A configured payload's `RetvalStopCodes` controls whether the bootstrapper continues after that nested payload and is not an outer process-return mapping.

Runtime validation confirms that bootstrapper exit code 0 alone is insufficient evidence of installation success. The wrapper can return 0 after a nested MSI fails, as observed for error 1639 and an unelevated error 1925. Installed-state validation must therefore verify the selected ProductCode and ARP tuple. AKInstallerMSI 3.5.200 and production 5.6 wrappers wrote the exact nested-MSI ProductCode, display metadata, registry view, and uninstall command returned by the parser when installation succeeded.

Interactive validation of two classic packages independently confirms the static ARP projection. Update-Download-Tool writes ProductCode `UDTMaker`, DisplayName `Update-Download-Tool`, DisplayVersion `1.7`, no Publisher, the 32-bit HKLM view, `C:\Windows\AKDeInstall.exe "/C:\Program Files (x86)\Update-Download-Tool\"`, and the compiled double separator in its DisplayIcon value. IncCopy writes ProductCode and DisplayName `IncCopy`, no DisplayVersion or Publisher, the same registry view and uninstaller-command grammar, and a single-separator DisplayIcon. Both outer launchers return 0 after successful interactive installation. IncCopy's `.inc` association appeared only after the wizard launched the installed application and has no corresponding compiled registry row, so it remains dynamic first-run evidence. AKPatch's compiled operating-system requirement rejects Windows 11 before installation and requires an older compatible VM for ARP validation.

The production regibox 3.0.3 wrapper identifies AKInstallerMSI 5.4.610 and selects `regibox_setup.msi`. VM installation wrote the parser-selected ProductCode `{623C51AB-E9A8-4E32-B216-ABDB2F999F61}` to the 32-bit HKLM uninstall view with DisplayName `regibox`, DisplayVersion `3.0.3`, Publisher `regify GmbH`, and the MSI-derived `.rgb` and `.rgbx` associations. This fixture verifies that bootstrapper strings do not override the nested MSI ARP owner.

## Trust hierarchy

For native media, explicit compiled uninstall registry rows outrank identity fields for ARP properties, while the compiled product version remains separate package-version evidence; both outrank PE version strings. For AKInstallerMSI, the nested MSI database outranks `Config.ini` display strings, which outrank outer PE resources. Footer markers and brand strings without a valid bounded catalog are never sufficient for detection.

## Current limits

- Native table versions or footer identities outside the verified classic GZip, modern RC4, and legacy XOR profiles are rejected rather than guessed.
- Native registry flag bytes beyond the six source-backed fields, classic file-row option bytes, nonliteral roots, and runtime-dependent conditions remain unresolved.
- Unknown future `STPLKNXN` applicability, operation, or phase codes remain raw evidence and produce a structured diagnostic.
- Mixed 32/64-bit native payload architecture requires inspecting extracted application binaries; if primary payload analysis fails, PackageArchitecture remains unresolved and never falls back to the outer setup stub.
- AKInstallerMSI prerequisites are reported as evidence and are not automatically translated to WinGet Dependencies.
- Spanned AKInstallerMSI ZIP media remains unsupported because no companion-volume fixture or source-backed volume naming rule is available; the parser rejects nonzero EOCD disk fields instead of reading an incomplete archive.
- Extension descriptors and payload keys are parsed, but dynamic DLL, script, service, firewall, driver, IIS, task-scheduler, Windows-feature, and arbitrary custom-action effects require extension-specific static analysis or VM validation.
- Classic native EULA gating, alternate registry views, custom or hidden ARP variants, prerequisite execution, and return-code propagation still require an installed-state VM matrix for each structurally distinct package before submission. The observed 2005-2006 route now has complete installed-file catalogs, primary payload architecture, three negative unattended-switch tests, and two exact interactive ARP and uninstall-command validations.

## References

- [AKInstaller](https://www.akapplications.com/products/akinstaller/index.html)
- [AKInstaller silent installation](https://www.akapplications.com/products/akinstaller/silent_install.html)
- [AKInstallerMSI](https://www.akapplications.com/products/akinstallermsi/index.html)
- [AKInstallerMSI silent installation](https://www.akapplications.com/products/akinstallermsi/silent_install.html)
- [AKApplications old versions](https://www.akapplications.com/service/old_install.html), used as a release catalog only because its archived downloads required credentials during this audit
- [Internet Archive capture of AKInstaller 4.4.505](https://web.archive.org/web/20161226230144id_/http://akapplications.com/downloads/inst/akinstaller.zip), used as a non-executed legacy structural fixture
- [Internet Archive capture of AKInstaller 4.5.750](https://web.archive.org/web/20170417160401id_/http://akapplications.com/downloads/inst/akinstaller.zip), used to confirm that the legacy table route and record families remained unchanged
- [Internet Archive capture of AKInstallerMSI 3.5.1](https://web.archive.org/web/20161228031150id_/http://akapplications.com/downloads/msi/installmsi.zip), used as a non-executed historical central-directory fixture
- [Internet Archive capture of AKInstallerMSI 3.5.200](https://web.archive.org/web/20170417160411id_/http://akapplications.com/downloads/msi/installmsi.zip), used to confirm the historical `AKI\x02` central-directory route
- [Internet Archive history of Update-Download-Tool](https://web.archive.org/web/*/http://www.akapplications.com:80/udt.zip), whose 2005 product media validates the complete classic file-row grammar
- [Internet Archive history of AKPatch Standard](https://web.archive.org/web/*/http://www.akapplications.com:80/akpatchstd.zip), whose 2005 and 2006 product media validate the same classic route with a different payload catalog
- [Internet Archive history of AKPackIt](https://web.archive.org/web/*/http://akapplications.com/downloads/akpackit/AKPackIt.zip), whose 2016 product media validates AKInstallerMSI 3.4.326 and whose 2007 media is a plain MSI
