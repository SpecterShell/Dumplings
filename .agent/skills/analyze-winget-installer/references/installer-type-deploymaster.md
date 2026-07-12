# DeployMaster

## When To Use

Use `InstallerType: exe` for installers built with DeployMaster.

## Detection

Strong evidence includes `DeployMaster`, `DeployMaster Installation`, or `deploymaster.com` strings.

### Parser API

```powershell
$Info = Get-DeployMasterInfo -Path $InstallerPath
```

The parser validates the post-PE transformed LZMA-like payload header and
reads PE identity and requested execution level. Current DeployMaster payloads
are not direct LZMA streams; `Expand-DeployMasterInstaller` rejects them
deterministically rather than applying an unsafe guessed transform.

## Manifest Shape

Switch documentation: [DeployMaster silent installation](https://www.deploymaster.com/manual.html#silent).

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # DeployMaster
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: /silent
    SilentWithProgress: /silent
    InstallLocation: /appfolder "<INSTALLPATH>"
```

## WinGet Defaults And Overrides

WinGet supplies no DeployMaster defaults for generic `InstallerType: exe`. Treat `/silent` and related fields as complete family-specific overrides, explicitly specify supported modes, and remove any switch not proved for the current package.

## Step-By-Step Analysis

### Step 1: Parse DeployMaster Metadata

Load PackageModule once and inspect the validated overlay evidence:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-DeployMasterInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, Scope,
  RequestedExecutionLevel, WritesAppsAndFeaturesEntry, CanExpand, Warnings
$Info.OverlayInfo
```

Do not infer payload metadata from the transformed compressed stream.

### Step 2: Attempt Extraction Only When Supported

`Expand-DeployMasterInstaller` is the bounded extraction entry point, but the currently recognized transformed format is intentionally unsupported. Keep the call guarded and treat a deterministic rejection as an unresolved format, not as permission to execute the installer:

```powershell
if ($Info.CanExpand) {
  Expand-DeployMasterInstaller -Path $InstallerPath -DestinationPath $DestinationPath
} else {
  Write-Warning 'DeployMaster payload cannot be expanded statically by this parser revision.'
}
```

### Step 3: Resolve ARP And Product Identity

The current parser exposes the common registry-evidence contract, but returns no literal writes for this format:

```powershell
$Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
```

When `ProductCode` and `WritesAppsAndFeaturesEntry` are null, verify the visible ARP entry in a VM. Do not infer ARP fields from DeployMaster marker strings alone.

For `Brinno.BrinnoVideoPlayer`, isolated VM validation produced an x86 HKLM
EXE entry keyed `Brinno Video Player`, with `WindowsInstaller` absent. This is
package evidence, not a universal DeployMaster ProductCode rule.

### Step 4: Validate Silent And Runtime Behavior

Verify accepted switch spelling and visible ARP behavior for each package.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) when transformed payload metadata, `/silent`, scope, or visible ARP identity cannot be proved statically.

## Known DeployMaster Packages

- `Brinno.BrinnoVideoPlayer`
