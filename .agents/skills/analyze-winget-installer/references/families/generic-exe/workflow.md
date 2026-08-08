# Generic EXE fallback workflow

## When to use

Use this page only after structured static detection fails. Known families must use their focused page even when WinGet's manifest `InstallerType` is generic `exe`.

## Detection

Run the static analyzer, then secondary Detect It Easy and Exeinfo PE diagnostics. Do not assign a family from a filename, icon, version string, archive signature alone, or an online `--silent` mention.

## Static analysis

Read [Generic EXE Fallback Parser Internals](../../internals/generic-exe/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Exhaust structured static detection

Use `Get-WinGetInstallerAnalysis` and [Installer analysis](../../workflows/installer-analysis.md). If no parser recognizes the file, record bounded PE, resource, archive, and string evidence without guessing command-line behavior.

### Find matching publisher evidence

Use `winget search` to find other accepted packages from the same publisher. Navigate directly to those manifest paths and corresponding Dumplings tasks. Reuse a switch only when the current artifact has the same installer family and configuration; publisher identity alone is insufficient.

### Identify nested payload and visible ARP ownership

Do not infer ARP type from the outer EXE. Route every extracted or downloaded payload through static analysis independently and follow [Installed-state and association workflow](../../workflows/installed-state.md) when the visible owner remains ambiguous.

### Determine architecture, scope, and elevation

Use payload architecture and installed executable evidence, not the bootstrapper stub or ARP hive alone. Treat UAC, privilege fallback, and per-user/per-machine behavior as unresolved until static control flow or VM evidence proves them.

### Validate generic switches one at a time

When no stronger evidence exists, test `/S`, `/silent`, `/quiet`, `-s`, `--silent`, and `--quiet` individually in a restored VM. Do not combine guesses. Accept a switch only when there is no blocking UI and installed files, visible ARP, scope, and process exit code agree. A zero exit code alone is insufficient.

Unknown EXE families require validation for cancellation, reboot handling, architecture, install location, and downloaded payloads. Specify only `interactive` and `silent` unless a distinct silent-with-progress route is proved.

Block submission when silent installation requires a response file, unavoidable user interaction, or unsupported automation. Before finishing, trace every manifest field to static evidence or a recorded VM result.

## Manifest shape

Keep all snippet fields at installer level according to the manifest-authoring [installer fields](../../../../author-winget-manifest/references/manifest/installer-fields.md) and [defaults](../../../../author-winget-manifest/references/manifest/defaults-and-return-codes.md) workflows. Add only fields proved by publisher documentation, structured evidence, a matching current package, or recorded VM validation.

```yaml
Installers:
- Architecture: x64
  InstallerType: exe
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: <COMPLETE-SILENT-COMMAND>
    SilentWithProgress: <COMPLETE-SILENT-WITH-PROGRESS-COMMAND>
```

Remove `silentWithProgress` and its switch when the installer does not implement a distinct supported mode.

## WinGet defaults and overrides

WinGet supplies no default switches for generic `InstallerType: exe`.

- Explicitly write the complete supported `InstallModes` array.
- Provide complete `Silent` and `SilentWithProgress` values; WinGet cannot infer or merge them.
- Keep no-reboot arguments in silent fields and mode-independent launch suppression in `Custom`.
- Add logging and install-location switches only when verified.
- Do not copy defaults from MSI, Inno, NSIS, Burn, or a guessed installer family.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) for every unproved switch, mode, exit code, scope, elevation route, architecture, payload download, and visible ARP entry. A zero exit code without installed-state evidence is insufficient.

## Known examples

Generic EXE is a fallback rather than a format. Use accepted packages from the same publisher and installer lineage instead of treating one package as a canonical generic example.
