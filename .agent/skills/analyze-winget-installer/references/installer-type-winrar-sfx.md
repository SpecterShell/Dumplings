# WinRAR GUI SFX

## When To Use

Use `InstallerType: exe` for WinRAR GUI self-extracting wrappers. These wrappers usually extract and execute a configured nested installer file.

## Detection

Strong evidence includes `WinRAR SFX`, `WinRAR self-extracting archive`, `RarSFX`, `SFX module by Alexander Roshal`, an embedded RAR marker plus a WinRAR SFX comment, or a successful `Get-WinRarSfxInfo` result.

## Manifest Shape

Switch documentation: [WinRAR GUI SFX commands](https://documentation.help/WinRAR/HELPGUISFXCmd.htm).

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # WinRAR GUI SFX
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /S
    SilentWithProgress: /S
```

## WinGet Defaults And Overrides

WinGet supplies no WinRAR GUI SFX defaults for generic `InstallerType: exe`. Compose the complete SFX forwarding syntax with the configured nested installer's arguments, explicitly specify supported modes, and never assume the nested MSI/EXE accepts wrapper-only switches.

## Step-By-Step Analysis

### Step 1: Parse SFX Comments And The Executed Command

Use `Get-WinRarSfxInfo -Path $InstallerFile` to decompress the RAR SFX comment and return every `Presetup=` and `Setup=` command with its resolved archive entry. Use `Expand-WinRarSfx` for bounded static extraction.

For example, the `Lakes.SCREENView` wrapper resolves `Setup=setup.exe /w` to its embedded InstallShield `setup.exe`; the `/w` argument is wrapper configuration evidence, not the nested installer's silent switch.

### Step 2: Route The Nested Installer And Visible ARP Owner

The visible Apps & Features entry comes from the nested installer, not from the wrapper. For WinRAR SFX + MSI/WiX, add `AppsAndFeaturesEntries[0].InstallerType: msi` or `wix` only when the nested installer writes a visible Windows Installer ARP entry. For WinRAR SFX + EXE, do not add MSI/WiX ARP fields unless the nested EXE itself exposes them.

### Step 3: Validate Forwarding, Quoting, And Exit Codes

WinGet cannot extract SFX payloads directly during install. The manifest switches must pass through to the configured nested payload in a package-specific way.

## Known Wrapper Compositions

- `Lakes.SCREENView`

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for configured command quoting, nested switch forwarding, visible ARP ownership, and outer exit-code propagation.
