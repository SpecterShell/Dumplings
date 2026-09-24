# AKInstaller and AKInstallerMSI workflow

## When to use

Use this workflow after `Test-AKInstaller` confirms a supported structural route: a classic native setup with concatenated GZip members, a later native AKInstaller setup with a compiled STP project table and protected ZIP, an AKInstallerMSI bootstrapper with an encrypted ZIP and `Config.ini`, or a direct embedded MSI whose Summary Information identifies AKInstallerMSI. All routes are generic EXE installer entries in WinGet; the nested MSI remains evidence for ProductCode, UpgradeCode, architecture, ARP behavior, and dependencies.

Do not identify this family from `AKInstaller`, `AKApplications`, or regify strings alone. The detector requires the corresponding footer and bounded catalog, or a structurally valid nested MSI with `AKInstallerMSI` in `SummaryInformation.CreatingApp`.

## Detection

Analyze the installer once, then retain the parser result:

```powershell
$Analysis = Get-WinGetInstallerAnalysis -Path $InstallerPath
$Info = Get-AKInstallerInfo -Path $InstallerPath
```

`Route` is `AKInstaller/NativeClassicGZip`, `AKInstaller/Native`, `AKInstaller/NativeLegacy`, `AKInstallerMSI/Bootstrapper`, `AKInstallerMSI/BootstrapperLegacy`, or `AKInstallerMSI/EmbeddedMsi`. `ProductLine` distinguishes the native and MSI products. Review `Diagnostics` and `UnresolvedFields` before using any field in a manifest.

## Binary structure

```text
AKInstaller native setup
+-- PE runtime
`-- overlay
    +-- ZipCrypto ZIP: A01, A02, A04, A09, A11, A12, Axx payloads
    +-- protected configuration: XOR A9, pipe-delimited password field
    +-- seven UInt32LE footer fields
    `-- ASCII >AKINST_SETUP< or >KAPI_SETUP<

AKInstaller classic native setup
+-- PE runtime and loader data
`-- overlay
    +-- consecutive GZip members
    +-- UInt32LE member count and variable-width member descriptors
    +-- six UInt32LE footer fields
    `-- ASCII >KAPI_SETUP<

AKInstallerMSI bootstrapper
+-- PE runtime
`-- overlay
    +-- ZipCrypto ZIP: Config.ini_, FileN<name>_, runtime helpers, UI resources
    |   `-- legacy central records: AKI\x02; current records: PK\x01\x02
    +-- password bytes XOR 54 and secondary bytes XOR C6
    +-- four UInt32LE footer fields
    `-- ASCII >INSTALLMSI_SETUP<

AKInstallerMSI direct route
+-- PE runtime
`-- embedded MSI compound file
    `-- SummaryInformation.CreatingApp = AKInstallerMSI V<version>
```

Read [AKInstaller internals](../../internals/akinstaller/overview.md) when investigating table records, encrypted payloads, footer validation, or a new generation.

## Manifest shape

All routes use `InstallerType: exe`. Native AKInstaller supplies its own switches:

```yaml
InstallerType: exe # AKInstaller
Scope: machine
ElevationRequirement: elevationRequired
InstallModes:
- interactive
- silent
InstallerSwitches:
  Silent: /silent 1 /NoReboot
  SilentWithProgress: /silent 1 /NoReboot
  InstallLocation: /installdir "<INSTALLPATH>"
ProductCode: <visible uninstall-key name>
```

`/silent 1` suppresses interaction and message boxes. `/NoReboot` prevents an automatic reboot and lets the process report 3010 instead of initiating a reboot and returning 1641. Native AKInstaller does not show installation progress in this mode, so keep `InstallModes` limited to `interactive` and `silent`; duplicate the same command under `SilentWithProgress` so WinGet can still perform an unattended installation when that switch slot is selected. Add `/eula` to `Custom` only when the exact project compiles a license page that needs explicit acceptance.

AKInstallerMSI has a distinct command line:

```yaml
InstallerType: exe # AKInstallerMSI
Scope: machine
InstallModes:
- interactive
- silent
- silentWithProgress
InstallerSwitches:
  Silent: /silent 2 /msiparam "REBOOT=ReallySuppress"
  SilentWithProgress: /msilimitui 67 /msiparam "REBOOT=ReallySuppress"
  Log: /logfile
ProductCode: <nested MSI ProductCode>
AppsAndFeaturesEntries:
- InstallerType: msi # or wix, from the nested MSI parser
  UpgradeCode: <nested MSI UpgradeCode>
```

The bootstrapper converts `@` in `/msiparam` to `/` before forwarding MSI parameters, but a production 5.6 wrapper returned MSI error 1639 when `@norestart` was forwarded. Use the MSI property `REBOOT=ReallySuppress` for reboot suppression; this form completed unattended installation and produced the expected ARP entry in VM validation. Use the nested parser's `InstallLocationProperty` to add an artifact-specific install-location value only when it is present and connected to installed components. Remove redundant Apps & Features fields during normal manifest optimization. Exact AKInstallerMSI analysis also suggests the documented actionable outer outcomes as `ExpectedReturnCodes`: 1602 `cancelledByUser`, 1618 `installInProgress`, 1625 `blockedByPolicy`, 1638 `alreadyInstalled`, 3010 `rebootRequiredToFinish`, and 1641 `rebootInitiated`. Do not author 0 because WinGet already treats it as success, and do not assign a specialized response to 1603 because the vendor uses it for several generic MSI failure paths.

## Static parsing

1. Inspect `Route`, `ProductLine`, `DisplayName`, `ProductVersion`, `DisplayVersion`, `Publisher`, `ProductCode`, `UpgradeCode`, `Scope`, `DefaultInstallLocation`, `AppsAndFeaturesEntries`, `Protocols`, `FileExtensions`, `PayloadFiles`, `Shortcuts`, `IniFileOperations`, `ExecutedPayloads`, `LaunchConditions`, `Permissions`, `DirectoryAttributeOperations`, `CompiledProperties`, `ExtensionModules`, `FileOperations`, and `Diagnostics` from the retained result. Use `ProductVersion` for package-version discovery and `DisplayVersion` only for ARP matching; historical projects can compile different values for those fields.

2. For `AKInstaller/NativeClassicGZip`, `AKInstaller/Native`, and `AKInstaller/NativeLegacy`, treat literal compiled `STPLD` registry rows as authoritative ARP evidence. The parser groups every explicit uninstall key, returns custom key names as ProductCode when one visible entry is primary, preserves hidden entries under `HiddenArpEntries`, and leaves ProductCode unresolved when several visible entries have no source-backed primary. `STPLC` rows describe installed files; `STPLB` rows are temporary support payloads. Classic rows contain three typed strings followed by a raw UInt32LE size, while later rows add a typed condition before that size; the parser selects this grammar from the validated container route. Review decoded file operations, directory attributes, properties, and extension descriptors when they affect installed state. Conditions remain attached to their rows and require runtime evidence when they are not statically resolved. The validated footer selects the classic GZip, modern RC4, or legacy XOR container and string-table profile; do not infer this profile from PE version resources or builder release dates. Classic media currently receives `InstallModes: [interactive]` and no suggested switches because its internal silent-state variable does not prove a public command-line spelling.

3. For `AKInstallerMSI/Bootstrapper` and `AKInstallerMSI/BootstrapperLegacy`, inspect `Configuration`, `LaunchConditions`, `NestedInstallers`, `PrimaryNestedInstaller`, `PrimaryNestedInstallerSelection`, and `PrerequisitePayloads`. Each payload preserves conditions, detection tests, install/start modes, reboot policy, failure policy, parameters, and `RetvalStopCodes`. The latter is a nested-payload continuation policy and is not the outer bootstrapper's WinGet `ExpectedReturnCodes`. The configured ProductCode, explicit `Start=2`, or a sole nested MSI must establish the primary payload; an ambiguous multi-MSI wrapper is rejected rather than projected from its first MSI. ProductCode, UpgradeCode, architecture, associations, scope, and the final visible ARP entry come from the selected MSI database. Embedded and external prerequisites are evidence only; do not convert them directly into WinGet dependencies without confirming which prerequisites are installed or downloaded at runtime.

4. For `AKInstallerMSI/EmbeddedMsi`, use the same nested MSI evidence. The outer PE may not expose a separate footer. Do not accept a generic appended CFB file without the AKInstallerMSI creating-application identity.

5. Expand only the files needed for the current decision:

   ```powershell
   Expand-AKInstaller -Path $InstallerPath -DestinationPath $Destination -Name '*.msi' -CollisionAction Rename
   ```

   Omit `-Name` to extract every normal installed or wrapper payload. Native extraction uses installed-relative STPLC paths. MSI-wrapper extraction uses logical `Config.ini` paths and removes physical `FileN` prefixes and trailing underscores. `-RawEntries` exports physical archive names under `_akinstaller`. Passwords are used internally and are never returned or logged. The extractor validates the complete selection and its byte limit before writing any file; set `MaximumExpandedBytes` and `MaximumEntries` explicitly when analyzing untrusted or unusually large media.

6. Treat `PackageArchitecture` from a nested MSI as authoritative for AKInstallerMSI. For native packages, verify mixed 32/64-bit projects against extracted application binaries because the setup stub architecture does not constrain every installed payload.

## Apps & Features

Native AKInstaller can write explicit uninstall registry rows. The parser resolves deterministic project variables, honors each row's create/type/uninstall/only-if-missing/error/slash flags, groups values by hive, view, and uninstall key, requires DisplayName for visibility, and honors `SystemComponent`. Use every returned `AppsAndFeaturesEntries` item when several visible keys are proven, but use installer-level ProductCode only when `PrimaryEntry` identifies one key. Use the parser's exact DisplayName because a project may intentionally include its version or another suffix.

AKInstallerMSI normally exposes the selected nested MSI ARP identity. Preserve the nested `InstallerType` only in AppsAndFeaturesEntries when it differs from the outer generic EXE type. Do not replace the nested ProductCode with a bootstrapper PE version or Config.ini display string.

## Scope and architecture

Native scope comes from the explicit ARP hive. HKLM is machine scope and HKCU is user scope. Mixed or conditional hives leave one global `Scope` unresolved. AKInstallerMSI scope follows the nested MSI installation context; `ALLUSERS=2` may permit context-dependent installation and should not be forced to machine or user without package or VM evidence.

The parser reports registry view and architecture evidence separately. `OuterArchitectureInfo` describes the setup runtime, while `PackageArchitecture` is emitted only from the extracted primary application and adjacent payload evidence. `RegistryViewEvidence: OuterRuntimeDefault` means the view follows the native runtime default and still requires VM validation if the project invokes a helper or explicit alternate-view operation. `requireAdministrator` maps to `ElevationRequirement: elevationRequired`; machine-scope ARP alone never proves `elevatesSelf`.

## Validation notes

Follow [VM validation](../../workflows/vm-validation.md). For native protected-ZIP media, test `/silent 1 /NoReboot`, capture exit code, verify every visible and hidden uninstall tuple, registry view, uninstall-command quoting, installed files, decoded file operations, directory attributes, shortcuts, associations, prerequisite launches, ACL effects, and extension-produced state, then start the installed application. Test `/eula` only when exact compiled or runtime evidence identifies a license gate. For classic GZip media, determine the accepted unattended syntax before adding silent fields; do not assume the later native command line. For AKInstallerMSI, test `/silent 2 /msiparam "REBOOT=ReallySuppress"` and `/msilimitui 67 /msiparam "REBOOT=ReallySuppress"` independently. Confirm launch-condition failures, prerequisite selection, primary-MSI routing, nested return-code propagation, and whether a reboot returns 3010 or 1641.

Validated on Windows 11: AKInstaller 6.6.225 completed `/silent 1 /NoReboot` with exit code 0 and wrote the parser-projected 32-bit HKLM uninstall tuple, `.stp` and `.rcc` associations, and an additional VC++ prerequisite entry. AKInstallerMSI 3.5.200 and production 5.6 media completed with `REBOOT=ReallySuppress`; both `silent` and `silentWithProgress` produced the selected nested MSI identity. The same 5.6 wrapper returned nested MSI error 1639 with `@norestart`. regibox 3.0.3 wrote ProductCode `{623C51AB-E9A8-4E32-B216-ABDB2F999F61}`, DisplayName `regibox`, DisplayVersion `3.0.3`, Publisher `regify GmbH`, and the expected 32-bit machine registry view; these values match the selected nested MSI. A direct embedded MSI with `ALLUSERS=2` installed to HKLM when elevated and failed unelevated with MSI error 1925, so keep `Scope` unresolved unless package-specific evidence establishes one context. The archived AKInstaller 4.5.750 builder installer recognized `/silent 1 /Eula /NoReboot` in its log but stalled after system-folder initialization on current Windows 11 in both service and interactive sessions; treat this as artifact-specific compatibility evidence and validate other legacy packages independently. IncCopy 3.0, Update-Download-Tool 1.9.10, and AKPatch Standard 1.1.100 classic media timed out with both `/silent 1 /NoReboot` and generic `/S`, leaving `AKSetup.exe` running and producing no ARP or installed-file state. Interactive elevated installs of IncCopy and Update-Download-Tool wrote the exact parser-projected ProductCode, DisplayName, optional DisplayVersion, 32-bit HKLM view, DisplayIcon, and quoted Windows-directory uninstaller command; both outer launchers returned 0. IncCopy must retain its original generic setup filename during validation because renaming it to `IncCopy.exe` triggers the package's close-running-application guard against its own outer process. IncCopy also created `.inc` only after the wizard launched the application; because no compiled registry row describes that association, retain it as dynamic first-run evidence rather than parser-authored installer evidence. AKPatch stops before installation on Windows 11 because its compiled launch condition permits only Windows 95 through Server 2003. Retain interactive-only manifest guidance for this classic route unless another structurally distinct artifact proves a working unattended route.

## Known examples

- AKApplications AKInstaller 4.4.505: legacy `>KAPI_SETUP<` footer, XOR table strings, explicit 32-bit machine ARP rows, and 162 installed-file records.
- AKApplications IncCopy 3.0: classic `>KAPI_SETUP<` route with sixteen concatenated GZip members, a variable-width catalog, legacy XOR table strings, ProductCode `IncCopy`, and five installed-file rows.
- AKApplications Update-Download-Tool package version 1.9.10: archived 2005 classic media with sixteen installed-file rows; fixed-position size decoding recovers `UDTMaker.exe`, x86 architecture, ProductCode `UDTMaker`, `%ProgramFiles%\Update-Download-Tool`, and the distinct ARP DisplayVersion `1.7`.
- AKApplications AKPatch Standard 1.1.100: archived 2005 classic media with fifteen installed-file rows and a primary x86 `AKPatchStd.exe`, confirming that the complete classic grammar is not product-specific.
- AKApplications AKInstaller 4.5.750: same bounded legacy footer and XOR table route with 164 installed-file records, confirming that the release change did not introduce another table profile.
- AKApplications AKInstaller 6.6.225: modern `>AKINST_SETUP<` footer, RC4 table strings, explicit machine ARP rows, installed-file mapping, and `.stp` and `.rcc` associations.
- AKApplications AKInstallerMSI 3.5.1: historical `AKI\x02` central-directory signatures, one nested MSI, and one external Windows Installer prerequisite.
- AKApplications AKPackIt 1.8.6: historical product media built by AKInstallerMSI 3.4.326 with the same `AKI\x02` central-directory route and nested-MSI ARP ownership.
- AKApplications AKInstallerMSI 3.5.200: same historical central-directory repair route and primary-MSI selection behavior as 3.5.1.
- AKApplications AKInstallerMSI 5.6.700: encrypted `Config.ini` wrapper containing a prerequisite and one primary MSI.
- AKApplications Update-Download-Tool 2.9.610: current vendor product built with AKInstallerMSI 5.6.651; the nested MSI supplies ProductCode `{D221035D-65A1-4F93-8EDF-1F27F0243042}`, UpgradeCode `{DAA0EC1E-BEB9-4E29-B955-E1354FF02839}`, x86 architecture, and `.udtl`/`.udtm` associations.
- `regify.regibox`: AKInstallerMSI 5.4.610 encrypted wrapper with one MSI; the parser's ProductCode, version, publisher, registry view, and `.rgb`/`.rgbx` associations match VM installed-state evidence.
- `regify.regipay`: direct embedded-MSI route with `AKInstallerMSI V5.5.700` Summary Information.

Other products from AKApplications are candidates, not automatic matches. Current MPIC Studio media identifies an unrelated `MPIC EntpackerSetup` runtime and must not be routed to this parser from publisher branding alone.

## Source references

- [AKInstaller product page](https://www.akapplications.com/products/akinstaller/index.html)
- [AKInstaller command line](https://www.akapplications.com/products/akinstaller/silent_install.html)
- [AKInstallerMSI product page](https://www.akapplications.com/products/akinstallermsi/index.html)
- [AKInstallerMSI command line and return codes](https://www.akapplications.com/products/akinstallermsi/silent_install.html)
- [AKApplications old versions](https://www.akapplications.com/service/old_install.html), which provides release labels while archived product downloads supply the structural evidence cataloged in the internals reference
- [Internet Archive history of AKApplications product downloads](https://web.archive.org/web/*/http://akapplications.com/downloads/*), used only for static historical fixtures whose hashes and parser routes are recorded in the test catalog
