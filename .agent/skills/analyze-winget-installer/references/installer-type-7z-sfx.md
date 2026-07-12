# 7z SFX

## When To Use

Use `InstallerType: exe` for 7z self-extracting wrappers. These wrappers usually extract and launch a configured nested installer instead of writing Apps & Features entries themselves.

## Detection

Strong evidence includes `;!@Install@!UTF-8!`, `;!@InstallEnd@!`, `7zS.sfx`, `7zSD.sfx`, `7-Zip SFX`, or a successful `Get-SevenZipSfxInfo` result.

## Manifest Shape

Switch documentation: [7z SFX switches](https://olegscherbakov.github.io/7zSFX/switches.html).

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # 7z SFX
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: -y
    SilentWithProgress: -y
```

## WinGet Defaults And Overrides

WinGet supplies no 7z SFX defaults for generic `InstallerType: exe`. The manifest must contain the complete outer SFX command line plus the nested installer's required arguments. Specify the supported modes explicitly and do not use archive-extraction switches that bypass the configured nested command.

## Step-By-Step Analysis

### Step 1: Parse The SFX Configuration And Executed Command

Use `Get-SevenZipSfxInfo -Path $InstallerFile` to parse the source-defined `;!@Install@!UTF-8!` block. `Commands` preserves repeated `RunProgram`, `AutoInstall`, and `AutoInstallX` entries and reports the `-ai` or `-aiX` trigger. It also separates modified-module execution prefixes such as `hidcon:`, `nowait:`, and `fm0:` before resolving the payload.

`ExecutedPayload` is the first default command for compatibility. Inspect `ExecutedPayloads` and every command before choosing switches. Use `Expand-SevenZipSfx` for bounded static extraction. The parser uses SharpCompress and does not require `7z.exe` or NanaZip.

### Step 2: Route The Executed Nested Installer And ARP Owner

Model the nested installer that writes ARP. Use `AppsAndFeaturesEntries[0].InstallerType: msi` or `wix` only when the nested installer writes a Windows Installer ARP entry. Omit MSI/WiX ARP fields for EXE+EXE chains unless the nested EXE exposes them.

### Step 3: Compare Wrapper Composition Examples

There are no current maintained reference packages.

### Step 4: Validate Switch Forwarding And Exit Codes

WinGet cannot extract SFX payloads directly during install. The manifest switches must drive the wrapper to extract and execute the configured payload with the nested installer's silent arguments.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) when the configured nested command, argument forwarding, visible ARP owner, or outer exit-code propagation remains uncertain.

## Implementation Sources

- [7-Zip SFX setup source](https://github.com/ip7z/7zip/blob/main/CPP/7zip/Bundles/SFXSetup/SfxSetup.cpp)
