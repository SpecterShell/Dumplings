# InstallShield classification

[Back to the InstallShield workflow](workflow.md)

## Classify and parse the InstallShield variant

Use `Modules\PackageModule\Libraries\Installers\InstallShield.psm1` to extract and classify InstallShield payloads without running the installer or shelling out to `ISx.exe`. The module contains an in-process parser based on the ISx container format; see the [ISx source repository](https://github.com/lifenjoiner/ISx). ISx is format attribution only: Dumplings neither distributes nor requires the ISx executable.

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-InstallShieldInfo -Path $InstallerFile
$Info.InstallShieldProjectType
$Info.InstallShieldRelease
$Info.InstallShieldStructuralRoutes | Format-Table RouteId, Layer, FormatVersion, SupportStatus
if ($Info.Variant -eq 'Advanced UI') {
  $Info.AdvancedUiInfo
  $Info.SuitePackages
} elseif ($Info.HasMsi) {
  $MsiInfo = Get-InstallShieldMsiInfo -Installer $Info
  $Info.MsiPayloadSelection
  $MsiInfo.SelectedMsiPath
} elseif ($Info.HasInstallScript) {
  $Info.InstallScriptInfo
}
```

Treat these three results independently. `InstallShieldProjectType` describes the authored installation model. `InstallShieldRelease` resolves the likely builder release from structured evidence. `InstallShieldStructuralRoutes` lists the physical handlers selected for each nested layer. Structural routes are authoritative for parsing: a newer wrapper can legally carry an older cabinet or InstallScript runtime.

`InstallShieldRelease` includes `ReleaseName`, `ProductVersion`, `SchemaVersion`, `Year`, `ServicePack`, `Build`, `Confidence`, `Candidates`, and `Evidence`. Disagreement between schema, suite namespace, MSI summary information, structured `Setup.ini` engine identity, and trusted runtime PE metadata lowers confidence and produces a warning; it never replaces a detected route. `SchemaVersion` is read only by `Get-InstallShieldProjectReleaseInfo` from the `InstallShield` table of a structured `.ism` XML export or binary Windows Installer project database. `SourceFormat` identifies which representation was read. Do not scan shipped setup binaries for a `SchemaVersion` string.

The `ISc(` value in `data*.hdr` always selects the proprietary cabinet format, but its release value depends on the encoding family. Legacy family `1` is not a builder product version: official InstallShield 11.5 media uses format 9.5. Modern families `2` and `4` use a builder-aligned version/100 value in the official outputs, including majors 31 and 32 for InstallShield 2025 and 2026. Keep the structural route independent even when a modern value contributes a release candidate. Preserve ambiguous candidates until an exact runtime, Setup.ini, project, suite, or MSI source narrows the identity.

Every route records `RouteId`, `Layer`, `Profile`, `FormatVersion`, `Handler`, `Capabilities`, `SupportStatus`, `Evidence`, and `Limitations`. Keep `Unsupported` and `Malformed` routes in analysis output. They identify which physical layer failed without discarding evidence from other layers.

An InstallShield 3 `setup32.exe` can be only the reusable setup engine. In that case `ContainerFormat` is `InstallShield 3 Engine` and the sole route is `Classic3/Engine` with `SupportStatus: Partial`. This proves the runtime release, not the package identity or behavior. Locate the accompanying `Setup.pkg`, `_setup.lib`, `data.z`, numbered disks, and `setup.ins` before authoring ARP metadata or switches. A complete Setup30 archive instead produces `Classic3/Package` and, when present, `Classic3/INS`.

A reusable launcher can also keep the application media outside the executable. `ContainerFormat: InstallShield External Media` and `Media/External` require an InstallShield-identifying launcher, one bounded direct `Setup.ini`, and a direct compiled script, validated `ISc(` header, or exact configured package. The parser reads only canonical sidecars in the launcher's directory; it does not recurse through the surrounding download folder. `ExternalMediaInfo` records the media root, engine version, ProductGUID, direct scripts and catalogs, and the evidence used to accept this relationship.

Use `Expand-InstallShieldInstaller` when file-level inspection is needed:

```powershell
$OutputDirectory = Join-Path $env:TEMP 'InstallShieldExtract'
Expand-InstallShieldInstaller -Path $InstallerFile -DestinationPath $OutputDirectory -CollisionAction Rename
```

When an extracted `data*.hdr` owns the application payload, use the managed cabinet extractor. Omit `-Name` to extract every valid entry; use `-Name` only for a reviewed wildcard selection. Parser-internal callers use `Rename` so duplicate catalog paths do not overwrite one another.

```powershell
$CabinetOutput = Expand-InstallShieldCabinet `
  -Path $Info.InstallShieldCabinetSupport.HeaderFiles[0] `
  -DestinationPath (Join-Path $env:TEMP 'InstallShieldCabinet') `
  -CollisionAction Rename
```

`Get-InstallShieldInfo` returns `Variant`, `HasMsi`, `HasInstallScript`, extracted MSI paths, InstallScript `.inx`/`.ins` paths, CAB/HDR paths, and extracted `*_sfx.exe` launchers. For Basic MSI and InstallScript MSI wrappers, it parses `Setup.ini`, reads `[Startup] PackageName` and the matching package section's `Location`, and exposes the exact path as `MsiPayloadSelection.SelectedMsiPath`. The configuration can be embedded or, for legacy media, beside `setup.exe`; `MsiPayloadSelection.SourceKind: ExternalSibling` identifies the latter. External-media resolution accepts only that safe, exact `.msi` path and never scans the sibling directory. `Get-InstallShieldMsiInfo` reads the selected MSI instead of taking the first `*.msi` match. `Get-MsiInstallerInfo` reports `InstallShieldProjectType` and its exact table/custom-action evidence.

If the publisher also serves that MSI directly, compare `Get-MsiInstallerInfo -Path` for the direct artifact with the exact `$MsiInfo` selected from `Setup.ini`. Prefer only the direct MSI when product code, upgrade code, version, architecture, scope, features, and visible ARP evidence match. Keep the EXE when it is required for InstallScript MSI launcher support, release-selected prerequisites, transforms, chained packages, or a distinct outer ARP entry. See [Choose between EXE and MSI](../../../../author-winget-manifest/references/package/artifact-selection.md#choose-between-exe-and-msi).

For Advanced UI media, reuse `$Info.AdvancedUiInfo` and `$Info.SuitePackages`. The former resolves `SuiteId`, ARP metadata, scope, and `INSTALLDIR`; the latter records every parcel's type, ID, identity attributes, file path/URL, operation targets, normal/silent arguments, elevation, detection condition, and whether MSI command lines set `ARPSYSTEMCOMPONENT=1`. Do not call `Get-InstallShieldMsiInfo` to obtain the outer ProductCode: nested MSI metadata is parcel evidence, while the suite ARP entry is authoritative.

`AdvancedUiInfo.InstallScriptEntryPoints` resolves literal `CallInstallScript` arguments, and `$Info.InstallScriptInfo` contains effects reachable only from those functions. `SilentSupport: NotApplicable` means the suite owns silent invocation; it is not evidence that every suite event is unattended. A reachable dialog requires VM validation of the containing event.

Evaluate target-specific package eligibility before selecting nested metadata, then dispatch only locally extracted targets. `Unknown` is a possible package, not evidence that it runs; `False` is statically excluded for the supplied facts. The dispatcher does not download package `SourceUrl` values.

```powershell
$Eligibility = Get-InstallShieldAdvancedUiPackageEligibility `
  -Info $Info.AdvancedUiInfo -Architecture x64 -OSVersion 10.0 -BuildNumber 26100 -ProductType Workstation
$NestedPackages = Get-InstallShieldAdvancedUiNestedPackageInfo `
  -Info $Info.AdvancedUiInfo -Architecture x64 -OSVersion 10.0 -BuildNumber 26100 -ProductType Workstation
```

Also inspect `Selections`, `Modes`, `Actions`, `Events`, `AbortConditions`, `Transactions`, and `WindowsFeatures` on `AdvancedUiInfo`. `Selections` is the authoritative mapping from a feature to parcel IDs, while the ordered `CatalogOrder` collection preserves package and transaction boundaries; `SuitePackages` contains only executable package entries. Each `When`, `Detect`, and abort predicate is returned as a structured condition tree. Registry, installed-state, property, parcel-state, and extension predicates are not evaluated against the analysis host; a listed or selected parcel is therefore not automatically an unconditional dependency. `PackageArchitectures` and each parcel's `Architecture` come only from explicit package platform metadata. `Resolve-InstallShieldSuiteCondition` evaluates only caller-supplied platform facts using `True`, `False`, and `Unknown`. Package-level `<Eligible>` and install-selection conditions affect eligibility; `<Detect>` describes installed state and operation planning and is deliberately excluded. Reuse the typed `ExitBehavior`, `RebootRequest`, `RebootCodes`, `UpgradeType`, and `TransactionMode` projections instead of reparsing raw property strings.

InstallShield setup prerequisites are separate `.prq` definitions. When they are extracted, reuse `$Info.PrerequisiteDefinitions`; release-selected references from `Setup.ini [ISSetupPrerequisites]` and MSI-authored feature references are available through `$Info.PrerequisiteReferences`, and `$Info.PrerequisiteEvidence` joins definitions only by exact identifier, description, filename, or filename stem. To inspect a reviewed definition directly, call it once and retain the result:

```powershell
$Prerequisite = Get-InstallShieldPrerequisiteInfo -Path .\Dependency.prq
$Prerequisite.Files
$Prerequisite.DetectionConditions
$Prerequisite.OperatingSystemConditions
$Prerequisite.InstallationConditionAnalysis
$Prerequisite.SilentCommandLine
$Prerequisite.ReturnCodesToReboot
$Prerequisite.RequiresAdministrativePrivileges
```

The `.prq` conditions describe when the child should run. Re-evaluate a reviewed target scenario by passing the exact `EvidenceKey` values returned by the first parse together with architecture and Windows facts: `Get-InstallShieldPrerequisiteInfo -Path .\Dependency.prq -ConditionEvidence $Evidence -Architecture x64 -OSVersion 10.0`. Missing target evidence remains `Unknown`; do not substitute the analysis host's registry or filesystem.

The `.prq` payload URL, checksum, condition, and command line describe the prerequisite package. They do not prove that the current release includes or selects it unless `Setup.ini`, the MSI, or the suite catalog references the same prerequisite. In the `.prq` Behavior record, `Lua="1"` means limited-user compatible and the absence of `Lua` means the prerequisite editor's default "requires administrative privileges" option remains enabled.

Inspect `$Info.RequestedExecutionLevel`, `$Info.ElevationRequirement`, and `$Info.ElevationRequirementEvidence`. Use `ElevationRequirement: elevationRequired` when the outer PE explicitly requests `requireAdministrator`, or when an exactly matched, release-selected prerequisite has `RequiresAdministrativePrivileges: true`. This prevents a silent setup from reaching an interactive child UAC boundary or exiting when a missing machine prerequisite cannot be installed. A selected prerequisite without `SilentCommandLine` still requires manual review: elevation alone does not make it unattended.

Do not infer required elevation from machine scope or from an unset MSI Word Count bit 3. The latter means elevation *may* be required, not that an already elevated parent is mandatory. `Vertexshare.WebpConverter` is a validated negative case: its machine MSI has the bit clear but silent installation works without elevation or preinstalled dependencies. Positive prerequisite examples include `AFAS.ProfitCommunicationCenter.7`, `AFAS.ProfitCommunicationCenter.8`, `NorconsultDigital.ISYLinker`, `Thorlabs.ThorlabsDeviceSDK`, and `Thorlabs.TSP01`.

For PackageForTheWeb media, inspect `ContainerFormat` and `PackageForTheWebCabinet`. `PackageForTheWebInfo` additionally records the extracted `Setup.ini` product identity, configured command line/package name, media-relative file list, exact root `NestedSetupPath`, selected `NestedPayloadPath`, and ordered `LaunchChain`. `ConfiguredCommandLine` belongs to the nested InstallShield launcher stage; do not treat it as an outer SFX switch. The cabinet object records the validated absolute CAB range, version, folder count, and file count. Extraction is still bounded by `-Name`, safe-path checks, collision policy, catalog counts, and total expanded bytes; neither the outer nor nested setup program is executed.

For InstallScript-only media, reuse `$Info.InstallScriptInfo`; do not parse `setup.inx` again. `SilentSupport` is `Supported`, `ResponseFileRequired`, or `Indeterminate`, and `ResponseFileRequirement` distinguishes `Embedded`, `External`, `None`, and `Unknown`. Only `Supported` is sufficient static evidence for the reported `SilentSwitches`. A reachable-path result that cannot be proven remains `Indeterminate` and requires VM validation.

`DialogTraces` contains the fresh-install and maintenance entry-point sequences. `Source: DirectBytecode` identifies ordinary named event handlers; `Source: FrameworkCallback` identifies the source-backed `_ShowWizardPages -> IfxOnShowWizardPages` route. A framework callback with reachable response-backed dialogs and no valid embedded `setup.iss` is reported as `ResponseFileRequired`, not `Indeterminate`. `EmbeddedResponseValidation` compares a shipped `setup.iss` with the reconstructed fresh-install order. A syntactically valid but mismatched response file does not prove self-contained silent support.

The same object contains the ARP and side-effect projection. Reuse `ProductCode`, `DisplayName`, `DisplayVersion`, `Publisher`, `Scope`, `DefaultInstallLocation`, `UninstallString`, `QuietUninstallString`, `DisplayIcon`, `URLInfoAbout`, `HelpLink`, `WritesAppsAndFeaturesEntry`, `AppsAndFeaturesEntries`, `RegistryWrites`, `RegistryItems`, `MediaRegistrySets`, `MediaRegistryWrites`, `ConditionalMediaRegistryWrites`, `CabinetFileGroups`, `CabinetComponents`, `MediaSetupTypes`, `MediaShellFolders`, `MediaShortcuts`, `ConditionalMediaShortcuts`, `Protocols`, `FileExtensions`, `ExecutedPayloads`, `FileOperations`, `DllOperations`, `PropertyHandlers`, `Shortcuts`, `OpcodeCoverage`, `UnsupportedOpcodes`, and `ArpValueSources`; do not parse the INX or cabinet header again with separate readers. Treat `DllOperations` as an opaque-code warning boundary, not as proof of the DLL's registry, file, or process effects. `PropertyHandlers` is structural compiler evidence and not a source of resolved runtime values. The `Features` and `SetupTypes` arrays on conditional media effects explain which authored selections can create them; they do not prove the runtime selection. The parser accepts `Setup.ini [Startup] ProductGUID` only when it is a valid GUID and requires compiled `MaintenanceStart`/uninstall-path evidence before promoting it to ARP `ProductCode`. A default media set can define additional visible uninstall keys; all distinct entries are returned while the MaintenanceStart GUID remains primary. If registration evidence is missing, `ProjectProductCode`, `ProjectName`, and `ProjectPublisher` remain diagnostic project metadata while manifest-facing ARP fields stay null. Registry-only values remain analysis evidence and are not inserted into WinGet `AppsAndFeaturesEntries`, whose schema accepts a smaller field set. The parser deliberately does not use `setup.iss [Application] Version`: response-file application metadata can be stale and is not the value written by `MaintenanceStart`.

Do not pass `-Name` during normal analysis. Use it only as a reviewed manual constraint when `MsiPayloadSelection.SelectionMethod` is unresolved and static inspection proves which payload the bootstrapper launches. If multiple MSIs are extracted and `Setup.ini` does not select one, the parser stops rather than using MSI architecture or enumeration order as a selector. An unselected MSI may be a prerequisite or chained package.

For direct MSI databases, `Get-MsiInstallerInfo` can also classify InstallShield authoring markers. `InstallShieldScriptActions` includes runtime actions and compiled custom actions with their sequence table, ordering, raw condition, opaque target, and resolved `Function`. When `Binary.ISSetup.dll` is present, `InstallShieldScriptInfo` exposes mapped `EntryPoints`, relative extracted support files, bounded analysis, and warnings without returning temporary paths. The parser opens the MSI once, streams the Binary-table payload through a 128 MiB bound, expands its validated `ISSetupStream`, and emulates only mapped functions. Reuse this result rather than extracting `ISSetup.dll` or parsing `Setup.inx` again.

`InstallShieldLauncherRequirement` reports whether `ISVerifyScriptingRuntime` proves that an InstallScript MSI must be launched through InstallShield `Setup.exe`; this verifier is launcher-contract evidence, not proof that the MSI contains an extractable INX program. Conditions are not evaluated outside Windows Installer. InstallShield-authored MSIs commonly use `INSTALLDIR="<INSTALLPATH>"`, but confirm with `$Info.InstallerBuilder -eq 'InstallShield'` because WiX and other builders can use the same public property.

InstallScript MSI classification does not prove support for Windows Installer's basic-UI `/passive` mode. `CrisisGo.CrisisGo` is a validated counterexample: a standard-user `/passive` invocation requests elevation and then opens an interactive InstallShield window. Its manifest therefore advertises only `interactive` and `silent`, with quiet mode used for the silent path. Test each InstallScript MSI in the VM before retaining `silentWithProgress`.

## Source references

- [InstallShield schema-version mapping discussion](https://stackoverflow.com/questions/29690042/find-installshield-version-used-for-creating-an-ism-file)
- [Historical InstallShield releases and documentation](https://zzz.buzz/notes/links-to-installshield-downloads-and-documentation/)
- [InstallScript Decompiler](https://github.com/jte/installscript-decompiler)
- [InstallShield reverse-engineering notes](https://hackmag.com/coding/installshield-reverse)
