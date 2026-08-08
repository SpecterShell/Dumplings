# 7z SFX workflow

## When to use

Use `InstallerType: exe` for 7z self-extracting wrappers. These wrappers usually extract and launch a configured nested installer instead of writing Apps & Features entries themselves.

## Detection

Strong evidence includes `;!@Install@!UTF-8!`, `;!@InstallEnd@!`, `7zS.sfx`, `7zSD.sfx`, `7-Zip SFX`, or a successful `Get-SevenZipSfxInfo` result.

## Static analysis

Read [7z SFX Parser Internals](../../internals/7z-sfx/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse the SFX configuration and executed command

Use `Get-SevenZipSfxInfo -Path $InstallerFile` to parse the source-defined `;!@Install@!UTF-8!` block. `Commands` preserves repeated `RunProgram`, `AutoInstall`, and `AutoInstallX` entries and reports the `-ai` or `-aiX` trigger. It also separates modified-module execution prefixes such as `hidcon:`, `nowait:`, and `fm0:` before resolving the payload.

`ExecutedPayload` is the first default command for compatibility. Inspect `ExecutedPayloads` and every command before choosing switches. Use `Expand-SevenZipSfx` for bounded static extraction. The parser uses SharpCompress and does not require `7z.exe` or NanaZip.

### Route the executed nested installer and ARP owner

Model the nested installer that writes ARP. Use `AppsAndFeaturesEntries[0].InstallerType: msi` or `wix` only when the nested installer writes a Windows Installer ARP entry. Omit MSI/WiX ARP fields for EXE+EXE chains unless the nested EXE exposes them.

### Compare wrapper composition examples

There are no current maintained reference packages.

### Validate switch forwarding and exit codes

WinGet cannot extract SFX payloads directly during install. The manifest switches must drive the wrapper to extract and execute the configured payload with the nested installer's silent arguments.

## Manifest shape

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

## WinGet defaults and overrides

WinGet supplies no 7z SFX defaults for generic `InstallerType: exe`. The manifest must contain the complete outer SFX command line plus the nested installer's required arguments. Specify the supported modes explicitly and do not use archive-extraction switches that bypass the configured nested command.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) when the configured nested command, argument forwarding, visible ARP owner, or outer exit-code propagation remains uncertain.

## Known examples

No accepted package currently serves as a dedicated 7z SFX example. Validate the configured nested command and switch forwarding before adding one.
