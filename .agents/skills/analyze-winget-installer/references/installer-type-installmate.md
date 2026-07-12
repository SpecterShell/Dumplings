# InstallMate

## When To Use

Use `InstallerType: exe` for Tarma InstallMate installers.

## Detection

Strong evidence includes `InstallMate`, `Tarma Installer`, or `Tarma Software`.

### Parser API

```powershell
$Info = Get-InstallMateInfo -Path $InstallerPath
```

The parser requires a bounded `tiz1` through `tiz4` archive header after the
PE image and before any Authenticode certificate. It reports archive schema,
PE identity, requested elevation, and named `ProductCode`/`PackageCode`
`StringFileInfo` values from the PE version resource. These named values are
explicit metadata, not arbitrary GUID probing. InstallMate's compressed TIZ
setup database is proprietary; `Expand-InstallMateInstaller` currently refuses
extraction and the parser does not guess ARP fields, associations, or scope
from compressed bytes.

## Manifest Shape

Switch documentation: [InstallMate setup command line](https://tarma.com/support/im9/setup/cmdline.htm).

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallMate
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /q2 /b0
    SilentWithProgress: /q1 /b0
    InstallLocation: '"INSTALLDIR=<INSTALLPATH>"'
    Log: /log:"<LOGPATH>"
  ExpectedReturnCodes:
  - InstallerReturnCode: 5
    ReturnResponse: cancelledByUser
  - InstallerReturnCode: 9
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 11
    ReturnResponse: systemNotSupported
  - InstallerReturnCode: 12
    ReturnResponse: rebootRequiredToFinish
  - InstallerReturnCode: 13
    ReturnResponse: packageInUse
  - InstallerReturnCode: 14
    ReturnResponse: alreadyInstalled
  - InstallerReturnCode: 16
    ReturnResponse: diskFull
  - InstallerReturnCode: 20
    ReturnResponse: installInProgress
  ProductCode: <ProductCode>
```

## WinGet Defaults And Overrides

WinGet supplies no InstallMate defaults for generic `InstallerType: exe`. Treat the documented InstallMate commands as complete overrides, explicitly state supported modes, and remove values not confirmed for the current installer generation.

## Step-By-Step Analysis

### Step 1: Parse InstallMate Metadata

Load PackageModule, parse once, and retain the generation-specific TIZ evidence:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-InstallMateInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, ProductCode,
  ProductCodeEvidence, PackageCode, Scope, RequestedExecutionLevel, CanExpand, Warnings
$Info.ArchiveInfo
```

Use `ProductCode` only when `ProductCodeEvidence` identifies the named PE `StringFileInfo.ProductCode` value.

### Step 2: Handle The Proprietary Setup Database

`Expand-InstallMateInstaller` is present as a safe, explicit rejection boundary. The current parser cannot decode the proprietary compressed TIZ database:

```powershell
if ($Info.CanExpand) {
  Expand-InstallMateInstaller -Path $InstallerPath -DestinationPath $DestinationPath
} else {
  Write-Warning 'InstallMate TIZ extraction is not implemented; no installer was executed.'
}
```

Do not replace this with arbitrary string probing or host execution.

### Step 3: Resolve Product And Uninstall Identity

```powershell
$Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
```

The compressed setup database prevents static recovery of literal ARP writes, so validate visible ARP fields in a VM.

For `Tarma.PublishOrPerish` 8.19.5300.9483, isolated VM validation produced a
machine-wide EXE entry keyed `{D7808C1C-93A9-4369-8385-A789888ED9D7}`, with
`WindowsInstaller` absent. Keep this as package-specific evidence.

### Step 4: Validate Generation-Specific Behavior

Verify accepted switch spelling because InstallMate packages may customize command-line handling.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for generation-specific switches, cancellation/reboot codes, scope, and visible ARP behavior.

## Known InstallMate Packages

- `WaveMetrics.IgorPro`
- `Tarma.PublishOrPerish`
