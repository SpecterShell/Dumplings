# IExpress

## When To Use

Use `InstallerType: exe` for Microsoft IExpress/WExtract self-extracting packages.

## Detection

Route here when `Get-IExpressInfo` succeeds, or named PE resources include `CABINET` and `RUNPROGRAM`. Supporting strings include `IExpress`, `WExtract`, `WEXTRACT`, `RunProgram=`, `InstallPrompt=`, and `Extracting files`.

## Binary Structure

IExpress/WExtract packages keep both configuration strings and one or more CAB files in named PE resources.

```text
WExtract PE stub
`-- .rsrc
    +-- RUNPROGRAM / POSTRUNPROGRAM  text command resources
    +-- ADMQCMD / USRQCMD            administrative/user command variants
    +-- other SED-derived settings  prompt and extraction behavior
    `-- CABINET*                     Microsoft CAB resources
        +-- 4D 53 43 46 ("MSCF")
        +-- folder/file catalog
        `-- compressed payloads

selected command -> script, EXE, or MSI from CAB catalog + configured arguments
```

PE resource RVAs are mapped through the section table; each resource size bounds its CAB or text. Resource names, not neighboring strings, associate commands with settings. The configured command is execution evidence, while CAB entry order is only physical catalog order.

## Manifest Shape

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

## WinGet Defaults And Overrides

WinGet supplies no IExpress defaults for generic `InstallerType: exe`. Use the configured `AppLaunched` command to compose complete outer and nested arguments, and explicitly specify supported modes. Do not substitute generic CAB extraction options for the command the package actually runs.

## Step-By-Step Analysis

### Step 1: Parse The SED Configuration And Extract Payloads

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

### Step 2: Route The Configured Nested ARP Owner

IExpress usually extracts files and runs the configured command. The visible Apps & Features entry comes from the nested installer or command rather than IExpress itself.

For IExpress + MSI/WiX, model the nested MSI/WiX ARP entry only when it is visible. For IExpress + EXE/custom command, model the nested command's ARP behavior. If the package only extracts files and does not install/register ARP, do not invent Apps & Features metadata.

### Step 3: Validate Command Quoting And Exit Propagation

If overriding the nested command is required, verify the exact quoting in a VM.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for nested command quoting, MSI argument forwarding, visible ARP ownership, and outer exit-code propagation.

## Known IExpress Packages

- `Microsoft.NetMon`: IExpress + WiX; visible ARP entry is WiX.
- `Microsoft.VCRedist.2005.x64`: IExpress + Visual Studio Setup Build Engine; wrapper command runs `vcredist.msi`.
- `Microsoft.VCRedist.2005.x86`: IExpress + Visual Studio Setup Build Engine; wrapper command runs `vcredist.msi`.
- `SonicWall.GlobalVPNClient` version `4.9.0.1202`: IExpress runs `RunMSI.exe`; the cabinet also contains `GVCInstall64.msi`.
