# MSI And WiX Installer Type

## When To Use

Use `InstallerType: msi` for a direct MSI database whose authoring system is not WiX. Use `InstallerType: wix` when static evidence identifies a WiX-authored MSI. This page also covers Advanced Installer-authored and InstallShield-authored direct MSI packages.

If an EXE wrapper invokes an MSI, keep the outer EXE installer type and use this page to analyze the nested MSI's product, upgrade, architecture, location, and visible ARP behavior.

## Detection

Route here when the file is a readable MSI database, `Get-MsiInstallerInfo` succeeds, or an archive/EXE wrapper exposes a nested MSI that is the effective visible ARP writer.

MSI and MSP files are both Compound File Binary files with magic bytes `D0 CF 11 E0 A1 B1 1A E1`. Distinguish them by root storage CLSID rather than filename extension:

- `{000C1084-0000-0000-C000-000000000046}`: Windows Installer package, merge module, or patch-creation properties file.
- `{000C1086-0000-0000-C000-000000000046}`: Windows Installer patch package (`.msp`), for example a `Macrobond.Macrobond` patch installer.
- `{000C1082-0000-0000-C000-000000000046}`: Windows Installer transform (`.mst`), not a standalone WinGet installer.

Do not route an MSP or MST through the direct MSI manifest shapes. Use structured CFB and Windows Installer database evidence rather than the file extension.

## Binary Structure

MSI, MSP, and MST are OLE Compound File Binary (CFB) containers. The root storage CLSID identifies the Windows Installer document class; database tables are streams inside the CFB hierarchy.

```text
CFB document
+-- 512-byte CFB header
|   +-- D0 CF 11 E0 A1 B1 1A E1   signature
|   +-- sector shifts and FAT roots
|   `-- DIFAT entries
+-- FAT / DIFAT / mini-FAT sectors
+-- directory stream
|   `-- Root Entry + storage/stream records (UTF-16LE names)
`-- Windows Installer streams
    +-- _StringPool / _StringData
    +-- SummaryInformation
    +-- encoded table streams       Property, Directory, File, Component, ...
    `-- embedded Binary/Icon/cabinet streams
```

```text
CFB header
Offset  Size  Field
------  ----  -------------------------------------------------
0x00    8     Magic: D0 CF 11 E0 A1 B1 1A E1
0x08    16    CLSID (normally zero in header)
0x18    2     Minor version, uint16 LE
0x1A    2     Major version, uint16 LE
0x1C    2     Byte order: FE FF (little-endian)
0x1E    2     SectorShift, uint16 LE
0x20    2     MiniSectorShift, uint16 LE
...     ...   FAT, directory, mini-stream, and DIFAT locations/counts
```

The root directory CLSID distinguishes MSI-family documents: `{000C1084-0000-0000-C000-000000000046}` for installer databases, `{000C1086-0000-0000-C000-000000000046}` for patches, and `{000C1082-0000-0000-C000-000000000046}` for transforms. Dumplings queries decoded database tables through Windows Installer APIs/DTF; WiX, Advanced Installer, and InstallShield are authoring systems over the same MSI storage. Builder classification and visible ARP behavior come from table/property evidence, not from a different outer magic.

## Manifest Shape

Use this shape when [Step 2](#step-2-classify-the-msi-builder) reports a non-WiX or unknown builder, [Step 3](#step-3-identify-the-visible-arp-entry) proves that the native MSI entry is visible, and the manifest identity agrees with the MSI metadata. Obtain `ProductCode` from `Get-MsiInstallerInfo.ProductCode`. Do not add `AppsAndFeaturesEntries` merely to repeat the MSI identity.

```yaml
Installers:
- Architecture: x64
  InstallerType: msi
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  ProductCode: <ProductCode>
```

Apply the WinGet defaults below. Add `Scope`, an install-location override, or Apps & Features metadata only when the later steps prove that it is required.

## Manifest Shape: WiX MSI

Use this shape when `$Info.InstallerBuilder` is `WiX`. If only a Boolean classification is needed, `Test-WiXInstaller` can inspect WiX summary strings, table names, properties, and custom-action markers; do not call it after `$Info` already supplies the same classification. Use [Step 6](#step-6-determine-install-location-switches-and-modes) to obtain the actual public install-directory property rather than assuming `INSTALLDIR`.

```yaml
Installers:
- Architecture: x64
  InstallerType: wix
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  ProductCode: <ProductCode>
```

WiX MSIs use properties including `INSTALLDIR`, `INSTALLLOCATION`, `APPLICATIONROOTDIRECTORY`, `INSTALL_ROOT`, and package-specific all-uppercase names. If `WIXUI_INSTALLDIR` exists, use it only when the referenced directory is actually connected to installed components; the parser performs this table check because the property can remain in a package with no usable location UI.

## Manifest Shape: Advanced Installer MSI

Use this shape when `$Info.InstallerBuilder` is `AdvancedInstaller` and `$Info.AppsAndFeaturesInstallerType` reports the native MSI entry. Advanced Installer commonly uses `APPDIR`, but retain the shown override only when `$Info.InstallLocationSwitch` returns it. The builder classification does not by itself prove the visible ARP type.

```yaml
Installers:
- Architecture: x64
  InstallerType: msi # Advanced Installer
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  InstallerSwitches:
    InstallLocation: APPDIR="<INSTALLPATH>"
  ProductCode: <ProductCode>
```

Keep the comment only when it explains useful generator-specific behavior. Remove `InstallerSwitches.InstallLocation` if the package instead uses WinGet's default `TARGETDIR="<INSTALLPATH>"`, and omit `AppsAndFeaturesEntries` when the native MSI ARP identity agrees with the manifest.

## Manifest Shape: Advanced Installer MSI With EXE ARP

Use this shape when `$Info.InstallerBuilder` is `AdvancedInstaller`, `$Info.HidesMsiAppsAndFeaturesEntry` is true, and `$Info.AppsAndFeaturesInstallerType` is `exe`. Advanced Installer can hide the native MSI entry through `ARPSYSTEMCOMPONENT=1` or `SystemComponent=1` and author a separate non-GUID uninstall key such as `[ProductName] [ProductVersion]`. Use `$Info.AppsAndFeaturesProductCode` for the visible key rather than the hidden MSI `ProductCode`.

```yaml
Installers:
- Architecture: x64
  InstallerType: msi # Advanced Installer
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  InstallerSwitches:
    InstallLocation: APPDIR="<INSTALLPATH>"
  ProductCode: <CustomARPProductCode>
  AppsAndFeaturesEntries:
  - InstallerType: exe
```

The Apps & Features entry exists because the visible ARP type differs from the outer MSI type. Don't include `UpgradeCode` because the installer type in the visible ARP is not MSI, and do not duplicate `ProductCode` inside the entry. Known example: `IPEVO.Vurbo-ai`.

## Manifest Shape: InstallShield MSI

Use this shape when `$Info.InstallerBuilder` is `InstallShield`. InstallShield-authored MSIs commonly use `INSTALLDIR`, but WiX and other builders can use the same property, so require static `IS*` tables, `InstallShield*` properties, or `IS*` custom actions before applying this classification.

```yaml
Installers:
- Architecture: x64
  InstallerType: msi # InstallShield
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  InstallerSwitches:
    InstallLocation: INSTALLDIR="<INSTALLPATH>"
  ProductCode: <ProductCode>
```

Retain the location override only when `$Info.InstallLocationSwitch` returns it. Omit `AppsAndFeaturesEntries` when the native MSI entry is visible and agrees with the manifest. `Housatonic.ProjectViewer365` is a current static-parser example. EXE-wrapped InstallShield packages route to `installer-type-installshield.md` first.

## Manifest Shape: Hidden MSI With `.msq` EXE ARP

Use this shape when `$Info.HasMsqAppsAndFeaturesEntry` and `$Info.HidesMsiAppsAndFeaturesEntry` are both true. These packages hide the native `{ProductCode}` entry and write a visible `{ProductCode}.msq` uninstall key. Use `$Info.AppsAndFeaturesProductCode`; do not append `.msq` manually. Inspect `$Info.AppsAndFeaturesEntries.MsqAppsAndFeaturesRegistryRows` and confirm that the visible entry does not set `WindowsInstaller=1` before classifying it as `exe`.

```yaml
Installers:
- Architecture: x64
  InstallerType: wix
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  ProductCode: '{MSI-PRODUCT-CODE}.msq'
  AppsAndFeaturesEntries:
  - InstallerType: exe
```

Choose the outer `InstallerType` from the MSI builder; the example uses `wix` because Figma's machine installer is WiX-authored. The visible entry is EXE-style because WinGet classifies ARP entries by `WindowsInstaller`, not by the database that created the registry key. Don't include `UpgradeCode` because the installer type in the visible ARP is not MSI, and do not duplicate `ProductCode` inside the entry. Known `.msq` examples include `Figma.Figma`, `Dizzion.Frame`, `MuteMe.MuteMe`, and `Tulip.TulipPlayer`.

Velopack-generated MSIs use the same custom-entry pattern with a visible `MSI:<PackageId>` key. For example, the Tower MSI hides its GUID-based native entry with `ARPSYSTEMCOMPONENT=1` and explicitly writes `Software\Microsoft\Windows\CurrentVersion\Uninstall\MSI:Tower` without `WindowsInstaller=1`. The MSI artifact therefore has a native `{GUID}` product code, while the visible WinGet-matchable entry is EXE-style with installer-level `ProductCode: MSI:Tower`; do not strip the prefix or reuse the Velopack EXE key `Tower` for the MSI entry.

## WinGet Defaults And Overrides

WinGet populates missing switch fields independently for both `InstallerType: msi` and `InstallerType: wix`:

| Field | WinGet default |
| --- | --- |
| `InstallerSwitches.Silent` | `/quiet /norestart` |
| `InstallerSwitches.SilentWithProgress` | `/passive /norestart` |
| `InstallerSwitches.Log` | `/log "<LOGPATH>"` |
| `InstallerSwitches.InstallLocation` | `TARGETDIR="<INSTALLPATH>"` |

With standard MSI behavior, the effective install modes are `interactive`, `silent`, and `silentWithProgress`. Apply these omission and override rules:

- Omit `InstallModes` when all three standard modes are supported. If the package supports a different set, write the complete supported array explicitly.
- Remove each `InstallerSwitches` child whose complete value is identical to the WinGet default. Missing children are populated independently.
- If a package needs a different value, explicitly write the complete replacement for that child. WinGet does not merge command-line tokens with the default value.
- Keep `/norestart` or an equivalent no-reboot argument in custom `Silent` and `SilentWithProgress` replacements.
- Keep mode-independent public properties or behavior arguments in `InstallerSwitches.Custom`.
- Omit `ExpectedReturnCodes` unless the package adds behavior not represented by WinGet's built-in MSI return-code mapping.

These defaults come from winget-cli [`GetDefaultKnownSwitches`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp).

## Step-By-Step Analysis

Follow the steps in order. Do not infer builder, architecture, scope, visible ARP identity, or install-location syntax from the filename or from one common property name.

### Step 1: Parse The MSI Metadata Once

Load PackageModule and call the detailed parser with the installer path:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-MsiInstallerInfo -Path $InstallerFile

$Info.DisplayVersion
$Info.DisplayName
$Info.ProductCode
$Info.UpgradeCode
$Info.AllUsers
$Info.InstallerBuilder
$Info.InstallLocationSwitch
$Info.AppsAndFeaturesInstallerType
$Info.AppsAndFeaturesProductCode
$Info.SupportedArchitectures
$Info.UnsupportedArchitectures
$Info.ElevationRequirement
$Info.ElevationRequirementEvidence
$Info.ChromiumEnterpriseMsiInfo
$Info.Protocols
$Info.FileExtensions
```

Do not follow this call with `Read-ProductCodeFromMsi`, `Read-UpgradeCodeFromMsi`, `Read-InstallerBuilderFromMsi`, location readers, ARP readers, or association readers for fields already present in `$Info`; those convenience functions reopen and parse the database.

Use a single-field `Read-*FromMsi` helper only when one isolated value is needed and no detailed result exists. Pass `TransformPath` or `PatchPath` to the same `Get-MsiInstallerInfo` call when transforms or patches materially change the effective MSI tables.

### Step 2: Classify The MSI Builder

Route from `$Info.InstallerBuilder`:

- `WiX`: use `InstallerType: wix` and the WiX manifest shape.
- `AdvancedInstaller`: retain `InstallerType: msi`, then select the native-MSI or custom-EXE ARP shape in Step 3.
- `InstallShield`: retain `InstallerType: msi` and use the InstallShield MSI shape. Do not confuse it with an InstallShield EXE wrapper.
- `Unknown`: use the generic MSI shape unless another structured table or summary marker proves the builder.

`Get-MsiInstallerInfo` currently returns `WiX`, `AdvancedInstaller`, `InstallShield`, or `Unknown`. Treat builder classification as authoring evidence, not as proof of visible ARP behavior or silent-install success. Use `Test-WiXInstaller` only when the Boolean is needed without the detailed result; do not parse the same file with both functions.

### Step 3: Identify The Visible ARP Entry

WinGet considers an ARP entry MSI-backed when its `WindowsInstaller` registry value is `1`; otherwise it treats the entry as EXE-style. The fact that an MSI database wrote a key does not make that key MSI-style.

Route using the combined `$Info` evidence:

- Native MSI visible: `HidesMsiAppsAndFeaturesEntry` is false and `AppsAndFeaturesProductCode` equals `ProductCode`. Keep `$Info.ProductCode` and omit Apps & Features overrides unless another parsed value differs.
- Custom EXE visible: `HidesMsiAppsAndFeaturesEntry` and `HasCustomAppsAndFeaturesEntry` are true, and `AppsAndFeaturesInstallerType` is `exe`. Use `$Info.AppsAndFeaturesProductCode` and the custom EXE ARP shape.
- `.msq` visible: `HidesMsiAppsAndFeaturesEntry` and `HasMsqAppsAndFeaturesEntry` are true. Use `$Info.AppsAndFeaturesProductCode`, inspect the `.msq` registry rows for `WindowsInstaller`, and use the `.msq` shape when the visible entry is EXE-style.
- Native and custom evidence conflict, or the custom key is conditional: route to Step 8 and compare ARP entries dynamically.

Do not model a hidden native entry. Exclude entries with `SystemComponent=1`, and use the product code of the visible entry at installer level. Existing manifests are supporting evidence only; re-evaluate the current MSI because authoring settings can change between versions.

### Step 4: Determine Architecture Support

Use these `$Info` properties together:

- `Template` is the MSI summary template and primary package-platform evidence.
- `SupportedArchitectures` reports operating-system architectures on which the package can run.
- `UnsupportedArchitectures` reports explicit incompatibilities suitable for review against `UnsupportedOSArchitectures`.

Set manifest `Architecture` from the MSI package and installed payload architecture, not merely from the downloader filename. An x64 MSI remains `Architecture: x64` even when Windows on ARM can run it through x64 emulation; do not create an arm64 installer entry from compatibility alone. For a nominally x86 MSI that installs x64 files or uses architecture conditions, inspect component and payload evidence. Never use `neutral` when the package contains binary files.

Route missing or contradictory template, condition, and payload evidence to Step 8. Known unsupported-architecture examples include `Talkdesk.Talkdesk`, `PaloAltoNetworks.PrismaAccessBrowser`, `BelgianGovernment.eIDmiddleware`, and `LastPass.LastPass`.

### Step 5: Determine Scope And Elevation

MSI can perform per-user or per-machine installation, but even per-user MSI products commonly register through system-level Windows Installer ARP data. This can cause WinGet to perceive a per-user MSI as machine-wide.

Apply the project convention:

- `$Info.AllUsers` is `1`: `Scope: machine` is safe.
- `$Info.AllUsers` is absent, empty, `2`, or another value: omit `Scope`; do not infer `user` from the property alone.
- Custom Registry-table ARP entries under HKCU or conditional scope actions: record the evidence, but validate actual Windows Installer product registration before asserting scope.

For dynamic validation, inspect the corresponding product registration under `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products` for machine context and under a user SID for user context. This supplements ARP location, which is not reliable enough for MSI scope by itself.

Evaluate elevation separately from scope. `$Info.ElevationRequirement` is
`elevationRequired` only when the parser finds an explicit launch condition,
effective Chromium enterprise product-tag and silent-command evidence, a
scheduled restart-as-admin action, or the exact early InstallShield
context-action layout observed to stop quiet non-elevated installation. Inspect every item in
`$Info.ElevationRequirementEvidence`; `Confidence: Explicit` comes from authored
behavior, while `Confidence: Observed` identifies a source-backed vendor layout
whose practical effect was confirmed in VM testing.

Do not infer `ElevationRequirement` from `ALLUSERS=1`, `Scope: machine`, writes to
HKLM/Program Files, services, drivers, no-impersonate deferred actions, or
`AllowsInstallWithoutElevation: false` alone. Windows Installer defines a clear
Summary Information Word Count bit 3 only as "elevated privileges can be
required," not proof that the current package rejects a non-elevated launch.

Known distinct layouts include:

- `CatoNetworks.CatoClient`: a custom SCM-access probe feeds an explicit elevation `LaunchCondition`.
- `Cribl.CriblEdge`: an elevation launch condition plus a scheduled `RestartAsAdmin` action. The action proves an attempted restart, not that an unattended invocation survives it.
- `PaloAltoNetworks.PrismaAccessBrowser`: Chromium enterprise MSI actions plus a no-UI-only plain `--silent` modifier. Its embedded updater is tagged `needsadmin=Prefers`, but the outer MSI signature is not; the MSI command therefore retains its authored default `needsAdmin=True`.
- `Cisco.NetworkRecordingPlayer` and `CrisisGo.CrisisGo`: an early InstallShield `ISSetAllUsers` action; treat its `Observed` evidence distinctly because Revenera defines the action itself as upgrade-scope synchronization, not a general elevation declaration.

If the parser returns no elevation requirement but immediate custom actions run
before the normal install transaction, compare quiet standard-user and elevated
invocations from the same VM checkpoint. Record both exit codes and the failing
action; do not execute the MSI on the host.

Do not use `ElevationRequirement: elevatesSelf` merely because `/passive`
displays a UAC prompt. The elevated continuation must complete unattended from
the original standard-user invocation. Current VM observations demonstrate why
this distinction matters:

- `CatoNetworks.CatoClient`, `Cribl.CriblEdge`, and the nested MSIs from `DisplayLink.GraphicsDriver` request elevation under `/passive` but still fail afterward; they succeed when `msiexec` is launched from an already elevated shell. Use `elevationRequired`.
- `CrisisGo.CrisisGo` requests elevation under `/passive`, then opens an interactive InstallShield window. Advertise only `interactive` and `silent`; overriding `SilentWithProgress` with the quiet command is a defensive fallback, not evidence that progress mode is supported.
- `Cisco.NetworkRecordingPlayer` and `PaloAltoNetworks.PrismaAccessBrowser` request elevation under `/passive` and complete after it is accepted. Their `/quiet` invocations still require an already elevated caller, so use `elevationRequired`, not `elevatesSelf`.

These are version-specific dynamic observations. Revalidate when the MSI's
custom actions or project type change.

#### Chromium Enterprise MSI Wrappers

Chromium's enterprise MSI is a WiX wrapper around a nested Chromium Updater or
standalone application installer. Inspect the parser's focused evidence instead
of treating it as an ordinary MSI:

```powershell
$ChromiumMsi = $Info.ChromiumEnterpriseMsiInfo

$ChromiumMsi.IsDetected
$ChromiumMsi.ProductTagSource
$ChromiumMsi.EffectiveNeedsAdmin
$ChromiumMsi.InstallCommand
$ChromiumMsi.SilentModifierActions
$ChromiumMsi.IsSilentAtNoUi
$ChromiumMsi.IsSilentAtBasicUi
$ChromiumMsi.SilentElevationBehavior
$ChromiumMsi.HasImmediateTagExtraction
$ChromiumMsi.DeferredInstallerAction
$ChromiumMsi.Notices
```

The source-defined action order first runs `ExtractTagInfoFromInstaller`, builds
a default `ProductTag`, optionally replaces it with the appended `TAGSTRING`,
builds `InstallCommand`, and finally runs `DoInstall` as a deferred,
no-impersonate custom action. Therefore:

- `ProductTagSource: OuterMsiTag` means the signed/appended tag overrides the
  default `SetProductTagProperty` value. Use `EffectiveNeedsAdmin`, not the
  default string retained in the CustomAction table.
- `UILevel=2` is no UI (`/quiet`) and `UILevel=3` is basic UI (`/passive`). A
  vendor action conditioned only on `UILevel=2` can pass `--silent` for quiet
  installation while leaving the nested updater interactive under passive
  installation.
- Chromium Updater deliberately refuses to display UAC for plain `--silent`.
  Only `--silent=allow-uac` permits that prompt. When the effective
  `needsadmin` value is `true` or `prefers`, the parser reports
  `SilentElevationBehavior: RequiresPreElevation` for a plain-silent path.
- MSI `NoImpersonate` grants elevated context only to deferred execution custom
  actions. It does not elevate the immediate `ExtractTagInfoFromInstaller`
  action. A vendor-modified extractor can therefore fail before the deferred
  nested installer is reached.

Current Chrome enterprise MSI fixtures are untagged, retain the default
`needsAdmin=True`, and include plain `--silent` in the base nested command for
all MSI UI levels. A UAC prompt observed from a standard-user Chrome MSI launch
can be Windows Installer elevating before `DoInstall`; it does not contradict
the nested updater's rule against prompting in plain-silent mode.

Current Prisma Access Browser fixtures contain an embedded updater tagged
`needsadmin=Prefers`, but the outer MSI's `DigitalSignature` stream has no
non-empty Omaha tag. Raw whole-file string scanning would incorrectly treat the
embedded tag as the MSI's `TAGSTRING`; the parser deliberately does not do that.
The MSI command retains its authored default `needsAdmin=True`, while a vendor
custom action appends plain `--silent` only when `UILevel=2`. Consequently,
`/quiet` requires an already elevated MSI context and can fail in its immediate
tag-extraction path, while `/passive` leaves the nested updater non-silent and
may display UAC. This explains the observed difference without treating the
product name as a parser rule.

During VM validation, record which process owns the UAC prompt and the last MSI
action reached in a verbose log. A prompt from `msiexec.exe` before deferred
execution, a prompt from the nested updater, and a prompt followed by an
unattended failure are different behaviors. Use `elevationRequired` unless the
original standard-user invocation completes unattended after elevation; a UAC
dialog by itself is not evidence for `elevatesSelf`.

### Step 6: Determine Install Location, Switches, And Modes

Use `$Info.InstallLocationProperty`, `$Info.InstallLocationSwitch`, and `$Info.InstallLocationSource`. The parser validates candidate public directory properties against the `Directory`, `Component`, and file-installation structure instead of selecting any all-uppercase property.

Route the result:

- `TARGETDIR="<INSTALLPATH>"`: omit `InstallerSwitches.InstallLocation` because it equals the WinGet default.
- Another verified public property such as `INSTALLDIR`, `INSTALLLOCATION`, `APPLICATIONROOTDIRECTORY`, `INSTALL_ROOT`, or `APPDIR`: write the complete returned `InstallLocationSwitch` override.
- No verified property: omit the field. Do not invent `INSTALLDIR` from builder convention.
- `WIXUI_INSTALLDIR` present but not connected to installed components: ignore it.

Then compare silent behavior with the WinGet defaults:

- Standard MSI quiet/passive behavior: omit `InstallModes`, `Silent`, `SilentWithProgress`, and `Log`.
- An MSI that turns `/passive` into interactive UI: explicitly omit `silentWithProgress` from `InstallModes`; if a defensive `SilentWithProgress` override is retained, map it to the verified quiet command rather than `/passive`.
- Package-specific complete replacements: write only the differing child fields and retain no-reboot behavior.
- License acceptance or another public property needed in all modes: put it in `Custom`; add `Agreements` only when the authoring skill's locale workflow also requires it.
- Custom actions that reject quiet/passive mode or return nonstandard codes: route to Step 8.

### Step 7: Record Associations And Build The Manifest

Reuse `$Info.Protocols`, `$Info.FileExtensions`, and `$Info.RegistryAssociationInfo`. They are derived from the MSI `Registry`, `Extension`, `ProgId`, `Verb`, and `MIME` tables. Do not call `Read-ProtocolsFromMsi` or `Read-FileExtensionsFromMsi` after `$Info` already exists.

Choose the manifest shape using the earlier results, then apply these rules:

- Use `ProductVersion`, `ProductName`, `ProductCode`, and `UpgradeCode` from structured MSI properties, not filename strings.
- Use `$Info.AppsAndFeaturesProductCode` instead of `$Info.ProductCode` when Step 3 proves a different visible uninstall key.
- Add `AppsAndFeaturesEntries` only for a meaningful visible mismatch in installer type, name, publisher, or version.
- Whenever an Apps & Features item is required and either the outer type or item type is `msi`, `wix`, or `burn`, include `$Info.UpgradeCode`.
- Do not duplicate installer-level `ProductCode` inside `AppsAndFeaturesEntries`.
- Recheck `InstallModes` and every `InstallerSwitches` child against the WinGet defaults. Remove equal values and retain complete non-default replacements.
- Preserve association fields even though they are not currently included in the public WinGet index; route first-run-only associations to Step 8.

### Step 8: Escalate Unresolved Behavior To VM Validation

Do not execute the installer on the host. Use the Hyper-V workflow when any required fact remains unresolved, especially:

- native and custom ARP entries conflict or depend on conditions;
- `.msq` or another custom entry's `WindowsInstaller` value is unclear;
- scope cannot be established from `ALLUSERS` and Windows Installer product registration;
- immediate launch conditions or custom actions may reject a quiet non-elevated invocation;
- component conditions or installed payloads conflict with summary-template architecture;
- custom actions may reject quiet/passive installation, reboot, or alter process exit codes;
- the install-location property is present but may not affect the installed payload;
- associations may be created only by a custom action or application first run.

Before finishing, verify that every manifest decision traces to `$Info`, structured MSI tables, or recorded VM evidence.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) when `ALLUSERS`/per-user behavior, custom EXE ARP entries, `.msq` entries, architecture, public install-location properties, or return codes remain unresolved.

## Implementation Sources

- [WiX Toolset](https://github.com/wixtoolset/wix)
- [Microsoft: Word Count Summary property](https://learn.microsoft.com/en-us/windows/win32/msi/word-count-summary)
- [Microsoft: MsiRunningElevated property](https://learn.microsoft.com/en-us/windows/win32/msi/msirunningelevated-)
- [Microsoft: Using Windows Installer with UAC](https://learn.microsoft.com/en-us/windows/win32/msi/using-windows-installer-with-uac)
- [Chromium enterprise standalone MSI source](https://chromium.googlesource.com/chromium/src/+/main/chrome/updater/win/signing/enterprise_standalone_installer.wxs.xml)
- [Chromium Updater functional specification](https://chromium.googlesource.com/chromium/src/+/main/docs/updater/functional_spec.md)
- [Chromium Updater user manual](https://chromium.googlesource.com/chromium/src/+/main/docs/updater/user_manual.md)
- [Revenera: ISSetAllUsers custom action](https://docs.revenera.com/installshield27helplib/helplibrary/IHelpISSetAllUsers.htm)
