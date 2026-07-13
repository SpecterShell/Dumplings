# InstallMate

## When To Use

Use `InstallerType: exe` for Tarma InstallMate installers.

## Detection

Strong evidence includes `InstallMate`, `Tarma Installer`, or `Tarma Software`.

### Parser API

```powershell
$Info = Get-InstallMateInfo -Path $InstallerPath
```

The parser requires a bounded `tiz1` through `tiz4` archive after the PE image
and before any Authenticode certificate. It decodes the raw-LZMA `tzf3` stream,
the first `tin*` setup-database record, structured InstallMate 11 install-level
evidence, and file records. It also reads named `ProductCode` and `PackageCode`
values from the PE `StringFileInfo` resource. These are explicit metadata, not
arbitrary GUID probing.

For InstallMate 11 database format 15.11, the structured install level is
authoritative. Older formats are decoded for files but currently fall back to
the PE requested execution level for scope. `asInvoker` maps to current-user
scope, `requireAdministrator` maps to machine scope, and `highestAvailable`
remains conditional without a decoded install-level record.

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
  ProductCodeEvidence, PackageCode, Scope, DefaultScope, SupportedScopes,
  SupportsDualScope, InstallLevel, InstallLevelName, ScopeEvidence,
  RequestedExecutionLevel, DatabaseInfo, CanExpand, Warnings
$Info.ArchiveInfo
$Info.FileEntries
```

Use `ProductCode` only when `ProductCodeEvidence` identifies the named PE `StringFileInfo.ProductCode` value.

### Step 2: Expand Nested Files When Needed

Use the same parsed `FileEntries` to select payloads. The file table does not
yet resolve component/folder objects, so extraction deliberately writes each
file below `Payload/<record-key>/` instead of inventing an installation path:

```powershell
if ($Info.CanExpand) {
  Expand-InstallMateInstaller -Path $InstallerPath -DestinationPath $DestinationPath
  Expand-InstallMateInstaller -Path $InstallerPath -DestinationPath $DestinationPath -Name '*.msi'
} else {
  Write-Warning 'The bounded InstallMate setup database could not be decoded.'
}
```

The extractor streams exact `tzf3` lengths through bounded LZMA decoding. It
does not execute setup. Duplicate file names remain distinct because record
keys are included in output paths.

### Step 3: Resolve Product And Uninstall Identity

```powershell
$Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
```

Custom registry records and the full component/folder graph are not decoded
yet, so validate visible ARP fields and associations in a VM. Use the named PE
`ProductCode` for uninstall identity when present. Do not turn conditional
scope evidence into duplicate WinGet installer entries unless the package
exposes a supported scope-selection command line.

For `Tarma.PublishOrPerish` 8.19.5300.9483, isolated VM validation produced a
machine-wide EXE entry keyed `{D7808C1C-93A9-4369-8385-A789888ED9D7}`, with
`WindowsInstaller` absent. Keep this as package-specific evidence.

### Step 4: Validate Generation-Specific Behavior

For format 15.11, interpret `InstallLevel` as follows:

- `0` (`NotChecked`): machine only, without an access check.
- `1` (`CurrentUser`): user only.
- `2` (`AllUsersOrCurrentUser`): machine when possible, otherwise user.
- `3` (`AllUsersQueryCurrentUser`): machine with an interactive user-scope fallback prompt.
- `4` (`AllUsers`): machine only.
- `5` (`Administrator`): machine only with administrator rights.

Levels 2 and 3 describe runtime fallback, not proof that command-line scope
selection exists. Verify accepted switch spelling because InstallMate packages
may customize command-line handling.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for
generation-specific switches, cancellation/reboot codes, custom registry
records, associations, and visible ARP behavior. For install level 3, verify
what silent mode does when all-users installation is unavailable because the
interactive fallback prompt cannot be answered.

## Known Packages

- `WaveMetrics.IgorPro`
- `Tarma.PublishOrPerish`

## Implementation Sources

- [InstallMate setup command line](https://tarma.com/support/im9/setup/cmdline.htm)
