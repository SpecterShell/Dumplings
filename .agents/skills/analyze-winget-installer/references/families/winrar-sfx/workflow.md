# WinRAR GUI SFX workflow

## When to use

Use `InstallerType: exe` for WinRAR GUI self-extracting wrappers. These wrappers usually extract and execute a configured nested installer file.

## Detection

Strong evidence includes `WinRAR SFX`, `WinRAR self-extracting archive`, `RarSFX`, `SFX module by Alexander Roshal`, an embedded RAR marker plus a WinRAR SFX comment, or a successful `Get-WinRarSfxInfo` result.

## Static analysis

Read [WinRAR GUI SFX Parser Internals](../../internals/winrar-sfx/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse SFX comments and the executed command

Use `Get-WinRarSfxInfo -Path $InstallerFile` to decompress the RAR SFX comment and return every `Presetup=` and `Setup=` command with its resolved archive entry. Use `Expand-WinRarSfx` for bounded static extraction.

For example, the `Lakes.SCREENView` wrapper resolves `Setup=setup.exe /w` to its embedded InstallShield `setup.exe`; the `/w` argument is wrapper configuration evidence, not the nested installer's silent switch.

### Route the nested installer and visible ARP owner

The visible Apps & Features entry comes from the nested installer, not from the wrapper. For WinRAR SFX + MSI/WiX, add `AppsAndFeaturesEntries[0].InstallerType: msi` or `wix` only when the nested installer writes a visible Windows Installer ARP entry. For WinRAR SFX + EXE, do not add MSI/WiX ARP fields unless the nested EXE itself exposes them.

### Validate forwarding, quoting, and exit codes

WinGet cannot extract SFX payloads directly during install. The manifest switches must pass through to the configured nested payload in a package-specific way.

## Manifest shape

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

## WinGet defaults and overrides

WinGet supplies no WinRAR GUI SFX defaults for generic `InstallerType: exe`. Compose the complete SFX forwarding syntax with the configured nested installer's arguments, explicitly specify supported modes, and never assume the nested MSI/EXE accepts wrapper-only switches.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) for configured command quoting, nested switch forwarding, visible ARP ownership, and outer exit-code propagation.

## Known examples

- `Lakes.SCREENView`
