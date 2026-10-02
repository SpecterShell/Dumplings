# Dell Update Package workflow

## When to use

Use this workflow for Windows Dell Update Packages (DUPs), including the outer downloads for `Dell.CommandUpdate`, `Dell.CommandUpdate.Universal`, and Dell driver/application packages referenced by the `#Dell` catalog task. The nested installer can use InstallShield, MSI, another supported EXE family, or an additional configured 7z SFX. Dell's catalogs also contain legacy wrappers and BIOS executables with different structures; catalog membership and company name do not establish the supported DUPFramework route.

## Detection

`Test-DellUpdatePackage` requires a valid PE identifying `DUPFramework.exe`, a bounded ZIP or 7z overlay, and a root `Mup.xml` with the Dell MUPDefinition namespace and one configured executable. Missing configured payloads remain explicit incomplete evidence. Unsupported containers and malformed configuration fail the probe. Package metadata identifiers, component IDs and release IDs are not ARP ProductCodes.

## Static analysis

```powershell
$Analysis = Get-WinGetInstallerAnalysis -Path $InstallerPath
$Info = ($Analysis.ParserResults | Where-Object { $_.Name -eq 'Dell Update Package' -and $_.Success }).Result.Metadata
$Info.Configuration
$Info.NestedInstallerInfo
$Info.Diagnostics
$Info.UnresolvedFields
```

For direct parsing, call `Get-DellUpdatePackageInfo`. Use `-SkipNestedAnalysis` only when catalog/configuration evidence is sufficient; it deliberately leaves installed-state identity unresolved. See [Dell binary internals](../../internals/dell-update-package/overview.md) for container bounds, XML records and command mapping.

`ProductName` and `ProductVersion` describe the package. `DisplayName`, `DisplayVersion`, `Publisher`, ProductCode, UpgradeCode, scope and visible ARP type come from the selected nested parser when available. `FrameworkVersion` and `OuterArchitecture` describe the DUP runtime. `PackageArchitecture` uses a unique supported OS architecture from MUP, while `NestedPackageArchitecture` records the selected installer platform. Neither establishes the architecture of every installed executable. Inspect multiple architecture alternatives rather than choosing the first one.

`Configuration` preserves behaviors, parameter mappings, vendor return-code mappings, inventory, content records and the exact executable reference. `PackageMetadata` retains bounded `SoftwareComponent` XML, including supported systems/devices, requirements in descriptive text, revision history and release attributes. Invalid optional `package.xml` produces an incomplete diagnostic without discarding valid MUP/container evidence. `ReleaseNotes` returns each language's revision-history text unchanged; pass the selected text through the normal release-note processing workflow.

Extraction uses the same static archive infrastructure as other wrappers:

```powershell
$Files = Expand-DellUpdatePackage -Path $InstallerPath -DestinationPath $Folder -CollisionAction Rename
$XmlFiles = Expand-DellUpdatePackage -Path $InstallerPath -DestinationPath $XmlFolder -Name '*.xml' -CollisionAction Rename
```

Omitting `Name` exports all physical wrapper files, including metadata and vendor support files. It does not run `/e`, download prerequisites, or recursively export installed application files. Keep support-file relationships intact when analyzing extracted media. Direct calls default to `Prompt`, which appears only after a collision; automation must select a noninteractive collision policy.

Nested metadata analysis stages only the selected file for a direct MSI; EXE routes retain vendor support files. Selection is case-insensitive, but the opened path uses the actual archive spelling. This matters when a case-sensitive staging directory contains `Setup.exe` while MUP selects `setup.exe`.

## Manifest shape

Prefer `/passthrough` when the selected nested technology provides additional switch types, such as vendor logging or installation location, or its known mode switches differ from the embedded MUP command. Obtain the artifact-specific route from `$Analysis.SuggestedManifestFields`. Retain configured wait flags, properties, transforms and scope options. A direct MSI installation-location switch must use the selected database's proven directory property; do not substitute a generic `TARGETDIR` or `INSTALLDIR`.

For CommandUpdate's parsed Basic MSI route, the preferred switch shape is:

```yaml
InstallerType: exe # Dell Update Package -> InstallShield Basic MSI
InstallModes:
- interactive
- silent
- silentWithProgress
InstallerSwitches:
  Silent: /passthrough /S /V/quiet /V/norestart
  SilentWithProgress: /passthrough /S /V/passive /V/norestart
  Interactive: /passthrough
  Log: /V"/log ""<LOGPATH>"""
  InstallLocation: /V"INSTALLDIR=""<INSTALLPATH>"""
  Custom: /clone_wait
```

This example requires the artifact's InstallShield MSI route and `INSTALLDIR` evidence. `/clone_wait` is retained from CommandUpdate 4.1.0's configured command, not added to every Dell package. Advanced UI uses its suite switches instead of MSI `/V` options. A nested known WinGet type still needs explicit switches here because the outer `InstallerType` remains `exe`.

Apply the preferred command explicitly before relying on its installed-state metadata:

```powershell
$Override = [ordered]@{
  InstallerSwitches = Copy-Object $Analysis.SuggestedManifestFields.InstallerSwitches
  InstallModes = @($Analysis.SuggestedManifestFields.InstallModes)
}
$Suggestion = Get-WinGetInstallerManifestSuggestion -InstallerUrl $InstallerUrl -InstallerPath $InstallerPath -Override $Override
```

Suggestions are advisory. Raw parser fields still describe the MUP command, and manifest updating preserves existing authored switches. Authoring with the explicit override reanalyzes the changed command; review its diagnostics and VM-validate the exact route before submission.

Fall back to the embedded MUP behavior when nested parsing is incomplete, the known switches add nothing and agree with MUP, an unresolved custom/SFX layer prevents direct forwarding, or configured arguments cannot be safely rewritten. For an artifact with a resolved unattended MUP behavior, the fallback outer entry is:

```yaml
InstallerType: exe # Dell Update Package
InstallModes:
- interactive
- silent
InstallerSwitches:
  Silent: /s
  SilentWithProgress: /s
  Log: /l="<LOGPATH>"
ExpectedReturnCodes:
- InstallerReturnCode: 2
  ReturnResponse: rebootRequiredToFinish
- InstallerReturnCode: 4
  ReturnResponse: missingDependency
- InstallerReturnCode: 5
  ReturnResponse: systemNotSupported
- InstallerReturnCode: 6
  ReturnResponse: rebootInitiated
```

Both routes retain the outer DUP return codes shown above. Add scope, elevation and ARP fields only when the selected payload or outer manifest proves them. In the fallback, `SilentWithProgress` intentionally uses the same silent command; this does not establish a progress-capable mode. Without a usable nested passthrough route, no unattended switches are suggested when the MUP behavior is absent, duplicated, uses unsupported command elements or requires unresolved values.

## WinGet defaults and overrides

WinGet has no DUP-specific defaults for `exe`, so explicitly author the selected command route. With the fallback `/s` route, MUP maps the outer behavior to vendor arguments; do not append InstallShield `/v`, MSI `/qn`, or other nested arguments directly. `/r` requests a reboot and is not included. `/f` bypasses some version checks and is not a normal installation argument. `/installpath` is package-dependent; do not add it merely because the framework's CLI documentation lists it.

### Passthrough overrides

Dell's `/passthrough` forwards the remaining command-line text to the vendor executable instead of using the default MUP arguments. It suppresses the wrapper UI, but the supplied vendor command can still show its own UI. Preserve the vendor's quoting and place all vendor options after `/passthrough`. Dell disallows the outer `/l`, `/f`, and `/capabilities` options with this route; logging after the delimiter must use the vendor's syntax. See the [Dell Intel adapters guide](https://dl.dell.com/manuals/all-products/esuprt_ser_stor_net/esuprt_pedge_srvr_ethnt_nic/intel-pro-adapters_user%27s%20guide4_en-us.pdf), Windows command-line installation section.

Pass the complete virtual command line when inspecting this route. This example targets the InstallShield payload in CommandUpdate 4.1.0; it is not a generic vendor command:

```powershell
$CommandLine = '"' + $InstallerPath + '" /passthrough /clone_wait /s /v"/qn"'
$Info = Get-DellUpdatePackageInfo -Path $InstallerPath -CommandLine $CommandLine
$Info.CommandBehavior
$Analysis = Get-WinGetInstallerAnalysis -Path $InstallerPath -CommandLine $CommandLine
```

`CommandBehavior.VendorArguments` is the effective tail; `DefaultVendorArguments` and `Configuration.Behaviors` retain the replaced MUP command as evidence. The parser forwards the effective command to nested analysis and withholds fields affected by overrides that the nested parser cannot simulate. It leaves unattended support unresolved and does not suggest the default `/s`, log switch, or install modes for a passthrough override. An unsupported replaced MUP command does not generate a warning about the caller's independent command.

Put `/passthrough` in each experience switch, including `Interactive`, followed by that experience's vendor options. Keep shared vendor options in `Custom`, vendor logging in `Log`, and the proven vendor directory option in `InstallLocation`. WinGet assembles the experience switch, then logging, then custom options, then installation location; putting the delimiter only in `Custom` would leave a vendor log option outside the passthrough tail. See [WinGet's argument assembly](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCLICore/Workflows/ShellExecuteInstallerHandler.cpp).

For a single verified command without optional logging or location, `Silent` and `SilentWithProgress` may contain only `/passthrough`, with the complete vendor command in `Custom`. Do not add the outer `/l` switch. Explicit caller passthrough commands are never replaced by family defaults. `Get-WinGetInstallerManifestSuggestion -Override` passes authored `Silent` and `Custom` switches into analysis before projecting metadata; manifest updating does the same with effective installer switches. Validate the exact assembled command rather than assuming that the default MUP behavior and the override produce identical installed state.

The MUP vendor return codes feed DUP's named outcome mappings. They are not the final process exit codes. For example, a nested `3010` maps to DUP reboot-required status `2`; the Universal package can map nested success `0` to that same reboot-required outcome. Preserve the distinction when authoring `ExpectedReturnCodes`.

## Apps & Features

The parser follows `executable/executablename` exactly. It does not pick an arbitrary MSI or EXE from the archive. For InstallShield MSI media, its Setup.ini-selected MSI supplies visible ProductCode, UpgradeCode and ARP fields. For Advanced UI media, the suite's own ARP identity takes precedence over its nested MSIs. Inventory keys under `SOFTWARE\Dell\ManageableUpdatePackage` and MUP inventory UpgradeCodes are detection evidence, not proof that the wrapper creates an uninstall entry. Unresolved nested parsing leaves DisplayName and DisplayVersion unset; package name/version remain separate wrapper facts.

An additional 7z SFX is followed only when it selects one embedded executable. `ExecutionChain` preserves proven wrapper commands even when the final child is unsupported. `NestedWrapperInfo` retains InstallShield prerequisite/container evidence separately from its selected MSI. Unrecognized custom launchers, ambiguous routes, hidden registration and dynamic custom actions remain diagnostic evidence. Preserve existing manifest identity during a partial update when the selected payload cannot supply it.

Watchdog Timer 2.0.0.1 illustrates the distinction: MUP selects `WDTSetup_MUP.exe`, a configured 7z SFX that selects Foxconn's `WDTAppSetUp.exe`. That custom launcher starts the adjacent InstallShield InstallScript `setup.exe`; the media includes `setup.ini`, `setup.inx`, cabinets, `setup.iss`, `uninstall.iss` and driver files, not an MSI. Static inspection confirms installation, maintenance and driver-specific command paths, but these are not a generic SFX forwarding contract. Do not assign the InstallShield GUID as wrapper ProductCode or reuse response-file switches until that command path and its installed state are validated.

The configured unattended arguments are forwarded into NSIS's static command-line simulation. Other parsers do not necessarily apply MSI property overrides or transforms. When arguments can alter identity, scope, visibility or installation location, the affected top-level fields become unresolved; the unmodified payload facts remain under `NestedInstallerInfo`. Review `DellUpdatePackage.Nested.CommandOverrides` rather than copying those defaults back into a manifest.

## Scope and architecture

Use nested scope evidence. The outer PE's `requireAdministrator` supports `ElevationRequirement: elevationRequired`; it does not identify which nested ARP hive is written. Keep `OuterArchitecture`, configured executable architecture and supported application architectures separate. A driver package can have an x64 OS requirement and an x86 launcher without implying an x86 application.

## VM validation

Follow the [VM validation workflow](../../workflows/vm-validation.md), then verify the selected `/passthrough` or fallback `/s` command, its exit code and final nested ARP together. For passthrough, check silent and progress commands separately and exercise vendor logging and installation-location options when authored. Dell platform/device/prerequisite checks can reject a Hyper-V guest before it reaches the vendor installer. Such a refusal does not prove the payload has no ARP or that its unattended switches are broken. Driver and firmware updates need a suitable test device; do not apply them merely to exercise parser code. Never pass `/r` during routine validation.

In a Windows 11 Hyper-V guest, CommandUpdate 4.1.0 completed `/s` with exit `0`. Both 5.7.2 variants returned `4` without the required .NET Desktop 10 runtime and made no captured ARP/association changes. With runtime 10.0.12 installed, Win32 completed with `0` and Universal with `2`. Their ProductCode, DisplayName, DisplayVersion, Publisher, machine scope and resolved installation location matched the nested parser. Win32 also installed Dell Core Services as a separate companion; Universal registered an AppX `dcu.centennial` protocol. Retain such companion effects separately from the main ARP identity. This validates unattended installation and registration, not hardware update functionality.

CommandUpdate 4.1.0 also completed `/passthrough /clone_wait /s /v"/qn ..."` with exit `0`. A test MSI property and vendor `/l*v` log placed after the delimiter appeared in the MSI log, confirming forwarding. The main ARP tuple matched the parser, and uninstall left no captured ARP, association, or PATH changes. This proves that command for that artifact; other vendor commands still need their own validation.

## Known examples

`Dell.CommandUpdate` 4.1.0 uses ZIP with file-absolute central-directory offsets. CommandUpdate 5.7.2 and its Universal variant use a 7z overlay selecting different InstallShield packages. Optimizer 6.3.5.0 ARM64 contains an InstallShield Advanced UI suite with multiple MSI payloads. Watchdog Timer Driver 2.0.0.1 selects an additional 7z SFX and a custom launcher; its inventory registration does not prove a visible uninstall key.

Historical catalog packages `CPNKY` (Intel chipset 9.3.0.1019), `NN71R` (OpenManage Client Instrumentation 8.1.0) and `GVCVP` (Intel Ethernet 15.7.0.0) use framework `003.000.000.000`, ZIP and MUP specification 2.1.0. NN71R selects `omcix64.msi` directly and supplies its MSI identity; the Intel launchers remain unsupported nested families. Legacy NVIDIA package `X2XJJ` uses `SVMSEZ32.bin` runtime identity, and BIOS package `K0T3Y` has another executable layout. They are deliberately not classified as DUPFramework.

To find historical coverage, use the `#Dell` source sequence: fetch `CatalogIndexPC.cab`, select a model's catalog from its `ManifestInformation.path`, then read each `SoftwareComponent` download path, version, release ID and catalog checksum. The model catalogs can retain old driver and management packages; the precedence catalog is another source. Verify the downloaded artifact against its catalog checksum, cache provenance with the fixture, and probe its actual structure before choosing a parser. Do not assume that every cataloged package uses the same outer runtime.
