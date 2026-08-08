# Paquet Builder workflow

## When to use

Use `InstallerType: exe` for Paquet Builder installers.

## Detection

Detection evidence includes `Paquet Builder`, `G.D.G. Software`, `installpackbuilder.com`, `PaquetBuilder`, or a PE product name such as `Paquet Builder Setup`.

## Static analysis

Read [Paquet Builder Parser Internals](../../internals/paquet-builder/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse Paquet Builder metadata

```powershell
$Info = Get-PaquetBuilderInfo -Path $InstallerPath
Expand-PaquetBuilderInstaller -Path $InstallerPath -DestinationPath $DestinationPath -CollisionAction Rename
```

The parser locates and validates the independent payload and Paquet Builder runtime 7z archives. It reports PE identity, requested elevation, payload files, protocols, and file extensions without executing setup. The runtime archive and payload archive must remain distinct when deciding which nested files belong to the installed application.

Paquet Builder 2026.1 and later recognize `/s` and `/silent` natively when the project keeps built-in recognition enabled. Older installers and customized projects may parse `%PARAMS%` with project-specific actions, so verify their exact silent switch.

### Resolve ARP and executed payload identity

The runtime uses exit code `0` for success, `1` for decompression failure, `2` for user cancellation, and `3` for an unexpected fatal error. Validate visible ARP fields in a VM.

### Validate SFX and runtime behavior

Do not infer current switch support from newer Paquet Builder documentation when analyzing older built installers.

## Manifest shape

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

## WinGet defaults and overrides

WinGet supplies no Paquet Builder defaults for generic `InstallerType: exe`. Treat parsed switches as complete overrides, explicitly specify supported modes, and do not retain arguments based only on generic SFX behavior.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) for project-enabled silent support, generation-specific exit codes, payload execution, and visible ARP fields.

## Known examples

- `GDGSoftware.PaquetBuilder` (`ProductCode: GDGSoftPB2019` in the current manifest).
