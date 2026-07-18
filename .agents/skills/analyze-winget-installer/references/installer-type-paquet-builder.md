# Paquet Builder

## When To Use

Use `InstallerType: exe` for Paquet Builder installers.

## Detection

Detection evidence includes `Paquet Builder`, `G.D.G. Software`, `installpackbuilder.com`, `PaquetBuilder`, or a PE product name such as `Paquet Builder Setup`.

## Binary Structure

The supported Paquet Builder layout appends two independently valid standard 7z archives to a PE launcher. Dumplings classifies them by catalog contents rather than physical order.

```text
PE launcher
`-- overlay
    +-- payload 7z archive
    |   `-- installed/nested application files
    `-- runtime 7z archive
        +-- pbfprop.dat
        `-- PBCore.dll / PBCore64.dll
```

Each archive starts with `37 7A BC AF 27 1C` and has its own start header, catalog, packed streams, and bounded range. Runtime markers classify the runtime archive; the other validated archive is the payload. The parser does not infer ARP behavior from archive adjacency and keeps extraction paths/counts/expanded bytes bounded.

## Manifest Shape

Package switch documentation: [Paquet Builder installer command line](https://www.installpackbuilder.com/help/automation-command-line/package-installer-command-line).

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Paquet Builder
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: /s
    SilentWithProgress: /s
  ProductCode: <ProductCode>
```

## WinGet Defaults And Overrides

WinGet supplies no Paquet Builder defaults for generic `InstallerType: exe`. Treat parsed switches as complete overrides, explicitly specify supported modes, and do not retain arguments based only on generic SFX behavior.

## Step-By-Step Analysis

### Step 1: Parse Paquet Builder Metadata

```powershell
$Info = Get-PaquetBuilderInfo -Path $InstallerPath
Expand-PaquetBuilderInstaller -Path $InstallerPath -DestinationPath $DestinationPath
```

The parser locates and validates the independent payload and Paquet Builder
runtime 7z archives. It reports PE identity, requested elevation, payload
files, protocols, and file extensions without executing setup. The runtime
archive and payload archive must remain distinct when deciding which nested
files belong to the installed application.

Paquet Builder 2026.1 and later recognize `/s` and `/silent` natively when the project keeps built-in recognition enabled. Older installers and customized projects may parse `%PARAMS%` with project-specific actions, so verify their exact silent switch.

### Step 2: Resolve ARP And Executed Payload Identity

The runtime uses exit code `0` for success, `1` for decompression failure, `2` for user cancellation, and `3` for an unexpected fatal error. Validate visible ARP fields in a VM.

### Step 3: Validate SFX And Runtime Behavior

Do not infer current switch support from newer Paquet Builder documentation when analyzing older built installers.

## Known Paquet Builder Packages

- `GDGSoftware.PaquetBuilder` (`ProductCode: GDGSoftPB2019` in the current manifest).

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for project-enabled silent support, generation-specific exit codes, payload execution, and visible ARP fields.
