# dotNetInstaller workflow

## When to use

Use `InstallerType: exe` for dotNetInstaller bootstrapper packages. dotNetInstaller is a self-extracting/chaining wrapper; it normally does not write the final Apps & Features entry itself.

## Detection

Route here when `Get-DotNetInstallerInfo` succeeds, or PE resources include `CUSTOM/RES_CONFIGURATION` and one or more `RES_CAB` resources.

## Static analysis

Read [dotNetInstaller Parser Internals](../../internals/dotnetinstaller/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse component conditions and executed commands

Use `Get-DotNetInstallerInfo -Path $InstallerFile` to read the embedded `CUSTOM/RES_CONFIGURATION` XML and list every install component, its OS/architecture filters, and its interactive/basic/silent command. `ExecutedPayloads` resolves component references against files in embedded `RES_CAB` resources.

Use `Expand-DotNetInstaller -Path $InstallerFile -DestinationPath $Folder -CollisionAction Rename` to extract the embedded cabinets without running the bootstrapper. Analyze all selected or required components; dotNetInstaller can conditionally chain more than one payload.

### Route the selected nested ARP owner

For dotNetInstaller + MSI/WiX, add `AppsAndFeaturesEntries[0].InstallerType: msi` or `wix` only when the nested installer writes a visible Windows Installer ARP entry. For dotNetInstaller + EXE, do not add MSI/WiX ARP fields unless the nested EXE writes them.

### Validate conditional component selection

Confirm bundled prerequisite handling and final ARP entry in a VM when multiple conditional components are present.

## Manifest shape

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # dotNetInstaller
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /q /nosplash /ComponentArgs "*":"/quiet /norestart"
    SilentWithProgress: /qb /ComponentArgs "*":"/passive /norestart"
    Log: /Log /LogFile "<LOGPATH>"
  ProductCode: <ProductCode>
```

## WinGet defaults and overrides

WinGet supplies no dotNetInstaller defaults for generic `InstallerType: exe`. Compose the complete bootstrapper arguments with the selected nested installer's switches, specify supported modes explicitly, and retain no-reboot behavior where the nested installer supports it.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) when component conditions select different nested payloads, prerequisite handling is conditional, or the final ARP owner and exit-code propagation are unresolved.

## Known examples

- `Wibu-Systems.CodeMeterRuntimeKit`: dotNetInstaller + MSI.
