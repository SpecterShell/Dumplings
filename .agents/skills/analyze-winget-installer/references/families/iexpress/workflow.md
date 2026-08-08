# IExpress workflow

## When to use

Use `InstallerType: exe` for Microsoft IExpress/WExtract self-extracting packages.

## Detection

Route here when `Get-IExpressInfo` succeeds, or named PE resources include `CABINET` and `RUNPROGRAM`. Supporting strings include `IExpress`, `WExtract`, `WEXTRACT`, `RunProgram=`, `InstallPrompt=`, and `Extracting files`.

## Static analysis

Read [IExpress Parser Internals](../../internals/iexpress/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse the SED configuration and extract payloads

Use `Get-IExpressInfo -Path $InstallerFile` to read named WExtract resources such as `RUNPROGRAM`, `ADMQCMD`, and `USRQCMD`, enumerate the embedded `CABINET` resource, and resolve script or installer references in those commands. Use `Expand-IExpressInstaller` for bounded static CAB extraction. This is stronger evidence than generic `IExpress`, `WExtract`, extraction UI, or filename strings and does not invoke `/C` or any installer process.

Common IExpress switches include `/Q` for quiet mode, `/T:<path>` for extraction target, `/C` to extract files only when supported by the package, and `/C:<cmd>` to override the install command. Package behavior varies, so do not copy switches without static command evidence or VM validation.

For Visual C++ 2005-style packages, accepted patterns may compose wrapper and payload switches:

```yaml
Installers:
- Architecture: x64
  InstallerSwitches:
    Silent: /Q /C:"msiexec /i ""vcredist.msi"" /quiet
    SilentWithProgress: /Q /C:"msiexec /i ""vcredist.msi"" /passive
    Interactive: /C:"msiexec /i ""vcredist.msi""
    Log: /log ""<LOGPATH>""
    Custom: /norestart"
```

For NetMon-style IExpress + WiX packages, `/Q` can be enough when the embedded command already launches the WiX/MSI payload correctly.

### Route the configured nested ARP owner

IExpress usually extracts files and runs the configured command. The visible Apps & Features entry comes from the nested installer or command rather than IExpress itself.

For IExpress + MSI/WiX, model the nested MSI/WiX ARP entry only when it is visible. For IExpress + EXE/custom command, model the nested command's ARP behavior. If the package only extracts files and does not install/register ARP, do not invent Apps & Features metadata.

### Validate command quoting and exit propagation

If overriding the nested command is required, verify the exact quoting in a VM.

## Manifest shape

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # IExpress
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: /Q
    SilentWithProgress: /Q
    Log: /L:"<LOGPATH>"
  ProductCode: <ProductCode>
```

## WinGet defaults and overrides

WinGet supplies no IExpress defaults for generic `InstallerType: exe`. Use the configured `AppLaunched` command to compose complete outer and nested arguments, and explicitly specify supported modes. Do not substitute generic CAB extraction options for the command the package actually runs.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) for nested command quoting, MSI argument forwarding, visible ARP ownership, and outer exit-code propagation.

## Known examples

- `Microsoft.NetMon`: IExpress + WiX; visible ARP entry is WiX.
- `Microsoft.VCRedist.2005.x64`: IExpress + Visual Studio Setup Build Engine; wrapper command runs `vcredist.msi`.
- `Microsoft.VCRedist.2005.x86`: IExpress + Visual Studio Setup Build Engine; wrapper command runs `vcredist.msi`.
- `SonicWall.GlobalVPNClient` version `4.9.0.1202`: IExpress runs `RunMSI.exe`; the cabinet also contains `GVCInstall64.msi`.
