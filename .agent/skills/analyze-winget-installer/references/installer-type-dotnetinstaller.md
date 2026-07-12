# dotNetInstaller

## When To Use

Use `InstallerType: exe` for dotNetInstaller bootstrapper packages. dotNetInstaller is a self-extracting/chaining wrapper; it normally does not write the final Apps & Features entry itself.

## Detection

Route here when `Get-DotNetInstallerInfo` succeeds, or PE resources include `CUSTOM/RES_CONFIGURATION` and one or more `RES_CAB` resources.

## Manifest Shape

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

## WinGet Defaults And Overrides

WinGet supplies no dotNetInstaller defaults for generic `InstallerType: exe`. Compose the complete bootstrapper arguments with the selected nested installer's switches, specify supported modes explicitly, and retain no-reboot behavior where the nested installer supports it.

## Step-By-Step Analysis

### Step 1: Parse Component Conditions And Executed Commands

Use `Get-DotNetInstallerInfo -Path $InstallerFile` to read the embedded `CUSTOM/RES_CONFIGURATION` XML and list every install component, its OS/architecture filters, and its interactive/basic/silent command. `ExecutedPayloads` resolves component references against files in embedded `RES_CAB` resources.

Use `Expand-DotNetInstaller -Path $InstallerFile -DestinationPath $Folder` to extract the embedded cabinets without running the bootstrapper. Analyze all selected or required components; dotNetInstaller can conditionally chain more than one payload.

### Step 2: Route The Selected Nested ARP Owner

For dotNetInstaller + MSI/WiX, add `AppsAndFeaturesEntries[0].InstallerType: msi` or `wix` only when the nested installer writes a visible Windows Installer ARP entry. For dotNetInstaller + EXE, do not add MSI/WiX ARP fields unless the nested EXE writes them.

### Step 3: Validate Conditional Component Selection

Confirm bundled prerequisite handling and final ARP entry in a VM when multiple conditional components are present.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) when component conditions select different nested payloads, prerequisite handling is conditional, or the final ARP owner and exit-code propagation are unresolved.

## Known Wrapper Compositions

- `Wibu-Systems.CodeMeterRuntimeKit`: dotNetInstaller + MSI.

## Implementation Sources

- [dotNetInstaller](https://github.com/dotnetinstaller/dotnetinstaller)
