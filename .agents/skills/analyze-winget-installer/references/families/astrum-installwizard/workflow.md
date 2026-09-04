# Astrum InstallWizard workflow

## When to use

Use `InstallerType: exe` with `# Astrum InstallWizard` when static analysis confirms a supported Astrum InstallWizard 1.x or 2.x PE overlay. The parser recovers explicit registry writes, Apps & Features identity, shortcuts, INI and text edits, staged file and interactive operations, requirements where their option layout is known, installation-item groups, stored or GZip payload records, generated-uninstaller data, and installed-binary architecture evidence.

Do not route an executable here from product strings or trailer bytes alone. Astrum identity is accepted only when the footer self pointer, protected configuration, installation-item table, and complete file catalog are mutually consistent.

## Detection

Run the analyzer, then use the strict detector when the result affects manifest authoring:

```powershell
$Analysis = Get-WinGetInstallerAnalysis -Path $InstallerPath
$IsAstrum = Test-AstrumInstallWizard -Path $InstallerPath
```

`Test-AstrumInstallWizard` requires a valid PE, a generation-specific self-referential footer, a valid twice-protected configuration, and file records that terminate exactly at the footer. Astrum 1.x uses a `0xE8`-byte footer and 60-byte file descriptors; early 1.x media has no final magic and therefore additionally requires `Astrum InstallWizard` and `Thraex Software` identity inside the PE image. Late 1.x and 2.x media append `3E 2D 1C 0B 78 56 34 12`; 2.x uses a `0xEC`-byte footer and 64-byte descriptors. Signed media is supported when the logical Astrum boundary appears before the PE certificate table.

## Binary structure

```text
PE32 setup runtime
+-- sections and resources
`-- overlay
    +-- protected configuration
    +-- optional UI/runtime records
    +-- generated-uninstaller GZip member
    +-- installation-item table
    +-- repeated file records
    |   +-- 60-byte 1.x or 64-byte 2.x descriptor
    |   +-- optional condition
    |   +-- bit-permuted destination name
    |   +-- volume-offset array
    |   `-- stored bytes or GZip member
    +-- 0xE8-byte 1.x or 0xEC-byte 2.x footer
    +-- footer pointer and optional signature block
    `-- optional late-1.x/2.x magic 3E 2D 1C 0B 78 56 34 12
```

Read [Astrum InstallWizard internals](../../internals/astrum-installwizard/overview.md) when debugging footer, configuration, catalog, extraction, or signed-media failures.

## Manifest shape

Astrum InstallWizard is a generic EXE family, so WinGet supplies no family-specific defaults. For structurally verified 2.x media, use the exact parser evidence:

```yaml
InstallerType: exe # Astrum InstallWizard
Scope: machine
ElevationRequirement: elevationRequired
InstallModes:
- interactive
- silent
InstallerSwitches:
  Silent: /silent
InstallerSuccessCodes:
- 1
ProductCode: <uninstall-key-name>
```

Use only fields returned by the exact artifact. The parser derives `ProductCode` from an explicit unconditional uninstall registry key. It does not infer that value from the application name when the registry record is absent or conditional. If the standard User Information dialog is compiled, the parser returns only `interactive` and omits `InstallerSwitches` because Astrum documents that `/silent` fails for that dialog. If the selected license dialog has the prohibit-silent option, the parser adds `/AcceptLicense` under `InstallerSwitches.Custom`.

Astrum 2.x documentation identifies process exit code `1` as successful completion. Keep `InstallerSuccessCodes: 1` for this generic EXE family after VM validation confirms the exact media follows that behavior. Astrum 1.x gained unattended installation during the 1.x line, but its binary configuration does not identify the builder subversion independently of the packaged application version. The parser therefore omits `InstallModes`, `InstallerSwitches`, and `InstallerSuccessCodes` for 1.x until builder-version or VM evidence proves them.

## Static parsing

1. Parse the installer once and retain the result:

   ```powershell
   $Info = Get-AstrumInstallWizardInfo -Path $InstallerPath
   ```

2. Review `ContainerRoute`, `FormatCatalogId`, `FormatGeneration`, `ConfigurationProfile`, `ProductCode`, `DisplayName`, `DisplayVersion`, `Publisher`, `Scope`, `DefaultInstallLocation`, `RequestedExecutionLevel`, `RegistryView`, `Diagnostics`, and `UnresolvedFields`. `astrum-1` and `astrum-2` identify catalogued overlay layouts; `Legacy1`, `Early2`, and `Modern2` identify configuration layouts selected within them rather than inferred builder editions. `ParserVersionInfo.CatalogVersion` records the descriptor schema used for the parse. Compiled ARP strings containing unresolved variables remain under `ArpEntries` and are omitted from manifest-facing `AppsAndFeaturesEntries` fields.

3. Inspect `RegistryWrites`, `Shortcuts`, `FileExtensionAssociations`, `ProtocolAssociations`, `IniOperations`, `TextOperations`, `FileOperations`, `InteractiveOperations`, `ResourceOperations`, and `ExecutedPayloads`. `ExecutedPayloads` contains the proven execute-program actions; other interactive action codes remain in `InteractiveOperations`. Conditional records are evidence, not guaranteed installed state. Analyze each configured nested executable separately before composing wrapper switches or assigning ARP ownership.

4. Inspect `InstallationItems`, `PayloadCatalog`, and `CompressionEvidence`. A destination beginning with `<InstallDir>` maps below the application root; other known destination roots are isolated under `_destinations` during extraction.

5. Review `Requirements`, `LicenseDialogSelected`, `LicenseAcceptanceRequired`, `UserInformationBlocksSilent`, `SilentInstallationDefault`, `NoUninstallation`, `X64ComplianceMode`, and `RequireAdmin`. Sparse requirement and policy offsets are projected only for `Modern2`, where controlled 2.29 builds establish them. `Legacy1` and `Early2` retain their option blocks as bounded evidence without applying modern offsets. `Astrum.Silent.LegacyRuntimeVersionRequired` keeps 1.x unattended behavior unresolved; `Astrum.Configuration.PartialTail` identifies only the remaining unassigned option bytes.

6. Expand only what the current decision needs:

   ```powershell
   Expand-AstrumInstallWizard -Path $InstallerPath -DestinationPath $Destination -Name '*.exe' -CollisionAction Rename
   ```

   Omit `-Name` to extract every installed payload file and the generated uninstaller when its configured installed path is resolvable. `-RawEntries` additionally exports the decoded configuration, raw footer, record headers, companion volumes, otherwise unplaced uninstaller data, and bounded pre-catalog gaps under `_astrum`. The pre-catalog gaps may contain compiled dialogs and images, but the parser deliberately does not assign a proprietary record type to an unrouted byte range.

   Supply spanned companion files in their physical order. The parser verifies their aggregate size against the virtual catalog gap before constructing a bounded disk-backed logical stream:

   ```powershell
   $Volumes = Get-ChildItem C:\Path\To\Setup -Filter 'Product.0*' | Sort-Object Name | Select-Object -ExpandProperty FullName
   Expand-AstrumInstallWizard -Path C:\Path\To\Setup\Product.exe -CompanionFile $Volumes -DestinationPath $Destination -CollisionAction Rename
   ```

7. Use `PayloadArchitectures` and `DependencyInfo` as installed-binary evidence. The parser selectively materializes up to 32 bounded EXE and DLL payloads, while the outer Astrum runtime is commonly x86 and does not prove the architecture of the application payload. Do not add dependency entries automatically without reviewing all returned evidence.

8. Resolve each structured diagnostic for the current workflow. `Astrum.Silent.UserInformationDialog` proves that a 2.x artifact is interactive-only, `Astrum.Silent.LicenseAcceptance` proves that `/AcceptLicense` is required, `Astrum.Silent.LegacyRuntimeVersionRequired` requires version or VM evidence before assigning 1.x switches, and `Astrum.Uninstall.Disabled` means the generated uninstaller is absent even if compiled ARP writes remain. Preserve existing manifest fields when other incomplete evidence does not affect the fields being refreshed.

## Apps & Features

Astrum 1.x and 2.x store Add/Remove Programs behavior as ordinary compiled registry operations. The parser groups unconditional values under `Software\Microsoft\Windows\CurrentVersion\Uninstall\<key>` and uses the key leaf as `ProductCode`. It reads display metadata, install location, uninstall commands, icon, URLs, comments, registry hive/view, and `SystemComponent` from the same record group.

An explicit unconditional ARP write is authoritative. Conditional writes, unresolved variable values, hidden entries, and custom shell actions remain evidence for VM validation. Add `AppsAndFeaturesEntries` only when nonredundant visible ARP fields differ from the locale identity or otherwise affect matching.

## Scope and architecture

Use the compiled registry hive first, then requested execution level and destination evidence. The supplied 2.29.50 media writes HKLM ARP entries and requests administrator elevation, so it is machine scope with `ElevationRequirement: elevationRequired`. The compiled `RequireAdmin` option also proves `elevationRequired` even when the PE manifest does not request elevation. Mixed or conditional hive evidence must remain unresolved until validated dynamically.

`X64ComplianceMode` selects the native 64-bit registry view on 64-bit Windows even though the Astrum runtime itself is a 32-bit PE. Use `RegistryView` from the parser rather than inferring the view from `OuterArchitectureInfo`.

Use architecture evidence from the installed application files. Never use `neutral` when any PE or other binary is present.

## Validation notes

Follow [VM validation](../../workflows/vm-validation.md). For 2.x, test the exact suggested command separately, capture exit code `1`, confirm the application files and generated uninstaller, and compare ARP, protocol, and file-extension snapshots. For 1.x, establish the builder release or test `/silent` and the process result before authoring either field. Test the application after installation and inspect configured nested commands. When the parser reports `LicenseAcceptanceRequired`, validate `/silent /AcceptLicense`; when it reports `UserInformationBlocksSilent`, do not claim unattended support without contradictory artifact-specific VM evidence.

Normal Astrum 1.x and 2.x single-file media are supported. `/tiny`, `/tinyverbose`, explicitly supplied spanned media, modern fixed-option projection, and Authenticode-after-payload routing are currently verified for 2.x. Companion files are never discovered by wildcard inside the parser: pass the complete ordered list and treat a missing or extra volume as an error.

## Known examples

- Astrum InstallWizard 2.29.50 builder installer: 124 catalogued files across two installation-item groups.
- Astrum InstallWizard 1.80 builder installer: legacy no-magic trailer, `0xE8` footer, 60-byte descriptors, and 148 catalogued files.
- Astrum InstallWizard 1.95.5 builder installer: late 1.x trailer magic and 209 catalogued files.
- Astrum InstallWizard 2.01.50 builder installer: early 2.x configuration with 64-byte descriptors and no modern encoding/internal-identity prefix.
- Astrum InstallWizard 2.21.20 builder installer: modern configuration profile and an Authenticode certificate after the Astrum logical image.
- Controlled tiny and tiny-verbose wrappers: one bounded GZip member containing the complete inner installer and a validated 96-byte wrapper descriptor.
- Controlled five-part spanned medium: one catalog record crossing the main EXE and four companion volumes.
- BreakAlube PC-GINA 1.0.1.5: five payload files across application, driver, and manual groups; its localized `<TimerName>` ARP template remains unresolved in static output.

## Source references

- [Thraex Software](https://www.thraexsoftware.com/)
- [Archived Astrum InstallWizard installer](https://web.archive.org/web/20130816053259/http://www.thraexsoftware.com/download/aiw.exe)
- [Archived Astrum InstallWizard download page](https://web.archive.org/web/20120410054204id_/http://www.thraexsoftware.com/aiw/download.html)
- [Archived Astrum InstallWizard version history](https://web.archive.org/web/20120410054204id_/http://www.thraexsoftware.com/aiw/version_history.txt)
- Astrum InstallWizard 2.29.50 builder-shipped help and sample project.
- Controlled installers generated with the documented `aiw2.exe /build` command.

The parser is an independently implemented Apache-2.0 component based on documentation, controlled builder output, and static binary observations. Proprietary builder files are neither copied nor redistributed.
