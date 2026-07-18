# Qt Installer Framework Installers

## When To Use

Use `InstallerType: exe # Qt Installer Framework` when the IFW binary-content cookie/parser identifies the installer. WinGet does not have a dedicated Qt IFW type.

Qt IFW has GUI-only and CLI-capable launcher variants. Only a CLI-capable launcher with its command-line interface enabled supports the silent manifest shape below.

Switch documentation: [Qt Installer Framework CLI](https://doc.qt.io/qtinstallerframework/ifw-cli.html).

## Detection

Call `Get-QtInstallerFrameworkInfo` before adding silent switches:

```powershell
$Info = Get-QtInstallerFrameworkInfo -Path $InstallerFile
$Info.InterfaceVariant
$Info.CommandLineInterface
$Info.SupportsSilentInstallation
$Info.PESubsystem
$Info.CommandLineInterfaceEvidence

Test-QtInstallerFrameworkCLI -Path $InstallerFile
Test-QtInstallerFrameworkSilentInstallation -Path $InstallerFile
```

The parser reads the PE optional-header subsystem first. `WindowsCui` identifies the CLI/headless launcher and `WindowsGui` identifies the GUI launcher. It also scans only the executable prefix before appended IFW resources for source-backed CLI option and command markers as corroborating evidence or as a fallback for malformed test fixtures.

Interpret the result as follows:

| Result | Meaning |
| --- | --- |
| `InterfaceVariant: CLI`, `CommandLineInterface: Enabled` | Silent CLI is available. |
| `InterfaceVariant: CLI`, `CommandLineInterface: Disabled` | CLI code exists, but `<DisableCommandLineInterface>true</DisableCommandLineInterface>` disables it. |
| `InterfaceVariant: GUI`, `CommandLineInterface: Unavailable` | GUI-only launcher; no WinGet-compatible silent installation. |
| `InterfaceVariant: Unknown` | Partial/ambiguous evidence; validate manually. |

Do not infer CLI support merely from Qt IFW cookies, `installerbase`, maintenance-tool strings, or the existence of generic command-line options.

### Install-Location Detection

Check whether the installer has a usable embedded `TargetDir`:

```powershell
$Info = Get-QtInstallerFrameworkInfo -Path $InstallerFile
$Info.TargetDir
$Info.RequiresExplicitInstallLocation
$Info.InstallLocationEvidence

Test-QtInstallerFrameworkRequiresInstallLocation -Path $InstallerFile
```

The CLI uses `--root` when supplied and otherwise falls back to config `<TargetDir>`. An empty `TargetDir` fails silent installation, so keep `--root "<INSTALLPATH>"` directly in both silent switches when `RequiresExplicitInstallLocation` is true. MSYS2 is a validated example.

When `RequiresExplicitInstallLocation` is false, omit `--root` from the ordinary silent switches and expose it as the optional `InstallLocation` switch instead.

## Binary Structure

Qt IFW appends binary content to the launcher and terminates it with a source-defined segment table and magic cookie. Segment pairs are `[offset:int64 LE][length:int64 LE]`, initially relative to the binary-content base and then mapped to absolute file ranges.

```text
PE installerbase launcher
`-- appended binary content
    +-- resource collection segment
    +-- N metadata resource segments
    +-- operations segment
    +-- resource/package archive data
    `-- trailer + cookie
```

```text
Trailer ending at EndOfBinaryContent (cookie end)
Field order                         Size
---------------------------------  ----
ResourceCollection range           16 bytes
MetaResource range[MetaCount]      16 bytes each
Operations range                   16 bytes
ResourceCount                      int64 LE
BinaryContentSize                  int64 LE
MagicMarker                        int64 LE
MagicCookie                        8 bytes
```

Cookies are `F8 68 D6 99 1C 0A 63 C2` for installer content and `F9 68 D6 99 1C 0A 63 C2` for DAT content. Supported marker values identify installer `0x12023233`, uninstaller `0x12023234`, updater `0x12023235`, and package manager `0x12023236`. Metadata may be Qt RCC data with 14-byte tree nodes; package payloads are standard 7z archives. Counts, segment arithmetic, RCC names, resources, archives, and expanded output are bounded before extraction.

## Manifest Shape

Use this when both `SupportsSilentInstallation` and `RequiresExplicitInstallLocation` are true:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Qt Installer Framework
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silentWithProgress
  InstallerSwitches:
    Silent: install --root "<INSTALLPATH>" --accept-licenses --default-answer --confirm-command
    SilentWithProgress: install --root "<INSTALLPATH>" --accept-licenses --default-answer --confirm-command
  UpgradeBehavior: uninstallPrevious
  # ProductCode: <ProductUUID> # Only when static metadata provides a deterministic value
```

Use this when a valid embedded target directory exists:

```yaml
  InstallerSwitches:
    Silent: install --accept-licenses --default-answer --confirm-command
    SilentWithProgress: install --accept-licenses --default-answer --confirm-command
    InstallLocation: --root "<INSTALLPATH>"
  UpgradeBehavior: uninstallPrevious
```

Do not author silent switches for GUI-only or CLI-disabled installers. Find another official installer build or block submission.

## WinGet Defaults And Overrides

WinGet supplies no Qt IFW defaults for generic `InstallerType: exe`. Treat the CLI commands in the selected shape as complete overrides and explicitly list the supported modes. GUI-only or CLI-disabled builds have no valid silent override and must not receive fabricated switches.

## Step-By-Step Analysis

### Step 1: Parse Metadata And Extract Required Payloads

```powershell
$Info = Get-QtInstallerFrameworkInfo -Path $InstallerFile
$Info.PackageName
$Info.DisplayVersion
$Info.Publisher
$Info.ProductCode
$Info.Scope
$Info.SupportedScopes
$Info.ScopeEvidence
$Info.RequiresExplicitInstallLocation
$Info.SupportsExistingInstallationOverride
$Info.RecommendedUpgradeBehavior
$Info.UpgradeEvidence
$Info.Warnings

$ExpandedPath = Expand-QtInstallerFramework -Path $InstallerFile -Name '*.exe'
Get-ChildItem -Path $ExpandedPath -Recurse -File
```

The parser reads IFW binary-content trailers and RCC metadata without execution. It maps config `<Name>`, `<Version>`, `<Publisher>`, and `<ProductUUID>` to manifest-authoring evidence.

`Expand-QtInstallerFramework` writes RCC files with their virtual paths, raw component archives under `metadata\<component>`, and selected files from embedded 7z archives under `packages\<component>\<archive>`. Extraction uses the GPL parser process with bounded, traversal-safe paths and no external archive executable.

### Step 2: Resolve Product UUID And Visible ARP Identity

On Windows, IFW uses `ProductUUID` for the uninstall key. If no UUID is embedded, IFW generates one at installation time and stores it in maintenance configuration. Do not invent `ProductCode`; prefer name/publisher matching or VM ARP validation.

### Step 3: Determine Upgrade Behavior

```powershell
Test-QtInstallerFrameworkSupportsExistingInstallationOverride -Path $InstallerFile
Read-UpgradeBehaviorFromQtInstallerFramework -Path $InstallerFile
```

Standard IFW installers do not overwrite an existing IFW installation in the same target directory. `PackageManagerCore::installationAllowedToDirectory` rejects the target when `<MaintenanceToolName>.exe` exists. Use `UpgradeBehavior: uninstallPrevious` so WinGet removes the previous installation first. Use `deny` instead only when the package intentionally does not support WinGet upgrades.

### Step 4: Determine Scope And Installed Architecture

IFW writes HKLM only when `AllUsers=true`; otherwise it writes HKCU. CLI-enabled installers can accept `AllUsers=true` or `AllUsers=false` as user arguments, so the parser reports both scopes only when the command-line interface is enabled. GUI-only or CLI-disabled installers report only their configured default scope.

When duplicating CLI-enabled user/machine entries, keep `Scope` and the corresponding `AllUsers` custom value on each installer entry.

Determine architecture from launcher support and installed binaries, not the ARP registry path.

### Step 5: Compare CLI And GUI Examples

CLI-capable and statically validated:

- `MSYS2.MSYS2`
- `reMarkable.reMarkableCompanionApp`

GUI-only and statically validated:

- Qt Linguist 5.12.2: `https://download.qt.io/linguist_releases/qtlinguistinstaller-5.12.2.exe`

Other Qt IFW family examples that must be classified individually:

- `TravisGoodspeed.MaskROMTool`
- `MoganLab.Mogan` (earlier versions)
- `KhronosGroup.VulkanSDK`

### Step 6: Validate Ambiguous Interface Or Script Behavior

Do not execute `--help` on the host to distinguish variants. Use PE subsystem and parser evidence. Require VM validation when `InterfaceVariant` is unknown, subsystem and marker evidence conflict, scripts conditionally modify `AllUsers`, the product UUID is generated at runtime, or the package requires a controller script.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) when CLI/GUI evidence conflicts, silent mode requires a target directory, existing-installation override is uncertain, or scripts conditionally change scope.

## Implementation Sources

- [Qt Installer Framework](https://github.com/qtproject/installer-framework)
