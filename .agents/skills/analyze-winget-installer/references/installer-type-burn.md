# Burn Installer Type

## When To Use

Use `InstallerType: burn` when WinGet invokes a WiX Burn bootstrapper bundle directly. A Burn bundle can register itself, chain MSI/WiX/EXE packages, or expose both bundle and package ARP entries, so do not infer the visible installed identity from the outer EXE alone.

## Detection

Route here when `Get-BurnInfo` succeeds, the PE section table contains `.wixburn`, or structured Burn manifest/bootstrapper data is available. The bundle PE architecture and filename are supporting evidence only; package conditions and chain metadata determine installed architecture and behavior.

## Manifest Shape

Use this shape when [Step 2](#step-2-identify-the-visible-arp-owner) proves that the Burn bundle writes the visible ARP entry, [Step 4](#step-4-determine-scope) finds one supported scope, and no Apps & Features override is required. Obtain the bundle `ProductCode` with `Read-ProductCodeFromBurn`. Add `Scope` only when `Get-BurnScopeInfo.DefaultScope` is conclusive.

```yaml
Installers:
- Architecture: x64
  InstallerType: burn
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  ProductCode: <ProductCode>
```

Do not create `AppsAndFeaturesEntries` solely to store the bundle `UpgradeCode`. Add the array only for a visible ARP mismatch, then include `UpgradeCode` because the outer installer type is Burn.

## Manifest Shape: Dual Scope

Use this shape only when `Get-BurnScopeInfo.SupportsDualScope` is true and the static evidence identifies a command-line-overridable scope variable. Python-style bundles qualify because they expose `InstallAllUsers` as an overridable variable and contain paired `_AllUsers` and `_JustForMe` package groups. Preserve the exact scope and location variable names returned by the current bundle; do not generalize this shape to every Burn package.

```yaml
Installers:
- Architecture: x64
  InstallerType: burn
  Scope: user
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallerSwitches:
    InstallLocation: DefaultJustForMeTargetDir=<INSTALLPATH>
    Custom: InstallAllUsers=0
  ProductCode: <ProductCode>
- Architecture: x64
  InstallerType: burn
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallerSwitches:
    InstallLocation: DefaultAllUsersTargetDir=<INSTALLPATH>
    Custom: InstallAllUsers=1
  ProductCode: <ProductCode>
```

The scope-specific `Custom` and `InstallLocation` values are non-default overrides and must remain on their respective installer entries. Do not use this shape merely because `PackageScopes` contains both user and machine packages; hidden or conditional package branches do not prove a WinGet-usable selector.

## Manifest Shape: Chained MSI/WiX Owns Visible ARP

Use this shape when [Step 2](#step-2-identify-the-visible-arp-owner) proves that the bundle registration is absent or hidden and a chained MSI/WiX package owns the visible entry. Parse that MSI with `Get-MsiInstallerInfo` and use its visible product code and upgrade code. Keep outer `InstallerType: burn` because WinGet invokes the bundle.

```yaml
Installers:
- Architecture: x64
  InstallerType: burn
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  ProductCode: <VISIBLE-MSI-PRODUCT-CODE>
  AppsAndFeaturesEntries:
  - UpgradeCode: <VISIBLE-MSI-UPGRADE-CODE>
    InstallerType: wix
```

Use `InstallerType: msi` in the Apps & Features entry when the chained package is not WiX-authored. Do not use chained MSI metadata when the MSI ARP entry is hidden and the Burn bundle entry remains visible.

## WinGet Defaults And Overrides

WinGet populates missing switch fields independently for `InstallerType: burn`:

| Field | WinGet default |
| --- | --- |
| `InstallerSwitches.Silent` | `/quiet /norestart` |
| `InstallerSwitches.SilentWithProgress` | `/passive /norestart` |
| `InstallerSwitches.Log` | `/log "<LOGPATH>"` |
| `InstallerSwitches.InstallLocation` | `TARGETDIR="<INSTALLPATH>"` |

With standard Burn behavior, the effective install modes are `interactive`, `silent`, and `silentWithProgress`.

- Omit `InstallModes` when all three modes are supported. If the bundle supports a different set, write the complete array explicitly.
- Remove each `InstallerSwitches` child whose complete value equals the WinGet default. Missing children are populated independently.
- Explicitly specify the complete replacement when a bundle uses different variables or arguments. WinGet does not merge tokens into a default child.
- Preserve `/norestart` or an equivalent no-reboot argument in custom silent replacements.
- Put mode-independent variables such as scope selection in `Custom`.
- Omit `ExpectedReturnCodes` unless the bundle has package-specific behavior beyond WinGet's built-in Burn/MSI return-code mapping.

These defaults come from winget-cli [`GetDefaultKnownSwitches`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp).

## Step-By-Step Analysis

Follow the steps in order. Burn's public parser separates bundle layout, XML metadata, scope, and architecture, so retain each detailed result and do not follow it with equivalent convenience readers.

### Step 1: Parse The Burn Evidence

Load PackageModule and collect each detailed evidence object without executing the bundle:

```powershell
. .\Modules\PackageModule\Index.ps1

$BurnInfo = Get-BurnInfo -Path $InstallerFile
$Manifest = Get-BurnManifest -Path $InstallerFile
$BootstrapperData = try {
  Get-BurnBootstrapperApplicationData -Path $InstallerFile
} catch {
  $null
}
$ScopeInfo = Get-BurnScopeInfo -Path $InstallerFile
$ArchitectureInfo = Get-BurnPackageArchitectureInfo -Path $InstallerFile

$ProductCode = Read-ProductCodeFromBurn -Path $InstallerFile
$UpgradeCode = Read-UpgradeCodeFromBurn -Path $InstallerFile
$ProductName = Read-ProductNameFromBurn -Path $InstallerFile
```

Use `$BurnInfo` for `.wixburn`, bundle code, machine, container, and engine-layout evidence. Use `$Manifest` and `$BootstrapperData` for registration, chain package, variable, and display metadata. Use `$ScopeInfo` and `$ArchitectureInfo` directly; do not then call `Read-ScopeFromBurn`, `Read-SupportedScopesFromBurn`, `Test-BurnDualScope`, `Read-UnsupportedArchitecturesFromBurn`, or `Test-BurnUnsupportedArchitecture` for the same installer.

The `Read-Product*FromBurn` helpers handle WiX-version fallback between bootstrapper application data and the Burn manifest. Keep their returned values with the detailed objects for the remaining steps.

### Step 2: Identify The Visible ARP Owner

Inspect bundle registration and every non-permanent chain package separately:

- Bundle registration: read `WixBundleProperties` and `BurnManifest/Registration`, including bundle ID/code, upgrade code, display name, `PerMachine`, and ARP settings.
- Chain packages: inspect package type, product code, visibility, permanence, install condition, and package-specific registration behavior.
- Hidden entries: exclude bundle or package entries marked hidden or `SystemComponent=1` when selecting the visible identity.

Route the combined evidence:

- Bundle registration is visible and represents the installed application: use the first manifest shape and bundle `ProductCode`.
- Bundle and chained package entries are both visible: determine which entry WinGet should correlate to the package. Add Apps & Features metadata only for the selected visible mismatch.
- Bundle registration is absent/hidden and a chained MSI/WiX is visible: parse the MSI with `Get-MsiInstallerInfo` and use the chained MSI/WiX shape.
- A chained EXE owns the visible entry: route that payload to its focused parser and do not invent MSI metadata.
- Visibility or conditions remain ambiguous: continue static analysis but require Step 8 before submission.

### Step 3: Determine Architecture

Use `$ArchitectureInfo.BundleArchitecture`, `SupportedArchitectures`, `UnsupportedArchitectures`, and `Packages` together. The bundle stub can be x86 while all installable packages are x64, as seen in x64-only Burn installers.

- Set manifest `Architecture` from the selected installable payload, not the Burn stub alone.
- Use package `InstallCondition`, architecture-specific package IDs/paths, and nested MSI metadata as stronger evidence than PE machine type.
- Treat `SupportedArchitectures` as operating-system compatibility, not a reason to duplicate one x64 payload as arm64.
- Add `UnsupportedOSArchitectures` only when the package conditions prove the exclusion.
- Never use `neutral` when the bundle installs binary files.

Known x64-only bundles with x86 stubs include `Sinew.Enpass` and `Jabra.Direct`; their package evidence excludes x86.

### Step 4: Determine Scope

Use `$ScopeInfo` in this order:

1. `DefaultScope` from `BootstrapperApplicationData/WixBundleProperties/@PerMachine`.
2. Fallback bundle registration scope from `BurnManifest/Registration/@PerMachine`.
3. `PackageScopes` as diagnostic chain evidence, not as automatic bundle scope.
4. `ScopeVariables` and `OverridableScopeVariables` to determine whether the user can select another scope from the command line.

Route the result:

- One supported scope: use that scope when the registration evidence is conclusive.
- `SupportsDualScope` true with a proven overridable selector: use the dual-scope manifest shape.
- Both package scopes but no overridable selector: keep only `DefaultScope`; do not create duplicate entries.
- Empty or contradictory scope: route to Step 8.

Most Burn bundles are machine scope. Known user-scope examples include `Crestron.AirMedia`, `DATEV.Belegtransfer`, `Grammarly.Grammarly.Office`, `IkiruPeople.VoyagerInfinitySaaSClient`, `PlanGrid.PlanGrid`, `Proton.ProtonDrive`, `RabbitCompany.Passky`, and `Slido.Slido`.

`Grammarly.Grammarly.Office` contains hidden all-users package branches but does not expose a supported command-line selector, so it remains user-only for manifest routing. Known dual-scope examples are `Python.Python.3.13` and `Python.Python.3.14`.

### Step 5: Determine Switches And Install Modes

Compare the bundle's actual behavior with the WinGet defaults:

- Standard quiet/passive behavior: omit `InstallModes`, `Silent`, `SilentWithProgress`, and `Log`.
- Scope, feature, or location variables: use bootstrapper overridable-variable evidence and preserve exact spelling and value syntax.
- Install-location variable differs by scope: keep complete scope-specific `InstallLocation` values on each entry.
- Custom silent replacements: retain no-reboot behavior and test whether the bootstrapper forwards or translates MSI options.
- Unverified variable or package condition: do not add it from a string match alone; route to Step 8.

### Step 6: Analyze Chained Payload Metadata And Associations

The Burn parser exposes chain evidence but does not infer all metadata written by every payload. For each payload that can execute on the selected path:

- MSI/WiX: use `Get-MsiInstallerInfo` for product/upgrade code, visible ARP type, architecture, install location, protocols, and file extensions.
- EXE: route to its focused parser and determine whether the bundle or payload owns ARP.
- Permanent prerequisite packages: record dependencies but do not automatically use their ARP identity as the package `ProductCode`.

If protocol or file-extension registration is performed only by a custom bootstrapper action or first application run, static Burn metadata is insufficient; route it to Step 8.

### Step 7: Build The Manifest

Select the manifest shape from the previous routes, then apply these rules:

- Use the visible bundle or payload product code, not merely the first GUID found in the chain.
- Add `AppsAndFeaturesEntries` only for a meaningful visible mismatch in type, name, publisher, or version.
- Whenever an Apps & Features item is needed for a Burn installer, include the corresponding `UpgradeCode`.
- Do not duplicate installer-level `ProductCode` inside `AppsAndFeaturesEntries`.
- Recheck `InstallModes` and each `InstallerSwitches` child against WinGet defaults; remove equal values and retain complete non-default replacements.
- Keep scope-specific `Custom` and `InstallLocation` leaves on their respective dual-scope entries.

### Step 8: Escalate Unresolved Behavior To VM Validation

Do not execute the bundle on the host. Use the Hyper-V workflow when any required fact remains unresolved, especially:

- bundle and chained package ARP ownership conflict;
- registration visibility depends on package conditions;
- package architecture differs from the stub or remains conditional;
- scope variables are present but not proven command-line-overridable;
- quiet/passive modes, no-reboot behavior, or exit-code forwarding are uncertain;
- nested payload associations or dependencies cannot be established statically.

Before finishing, trace every decision to `$BurnInfo`, `$Manifest`, `$BootstrapperData`, `$ScopeInfo`, `$ArchitectureInfo`, a nested parser result, or recorded VM evidence.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for conditional chain registration, bundle-versus-payload ARP ownership, scope routes, quiet/passive behavior, and outer/nested exit-code forwarding.

## Implementation Sources

- [WiX Toolset](https://github.com/wixtoolset/wix)
