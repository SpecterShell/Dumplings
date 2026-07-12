# Generic EXE Fallback

## When To Use

Use this page only after structured static detection fails. Known families must use their focused page even when WinGet's manifest `InstallerType` is generic `exe`.

## Detection

Run the static analyzer, then secondary Detect It Easy and Exeinfo PE diagnostics. Do not assign a family from a filename, icon, version string, archive signature alone, or an online `--silent` mention.

## Manifest Shape

Keep all snippet fields at installer level according to the authoring skill's `manifest-workflow.md`. Add only fields proved by publisher documentation, structured evidence, a matching current package, or recorded VM validation.

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

## WinGet Defaults And Overrides

WinGet supplies no default switches for generic `InstallerType: exe`.

- Explicitly write the complete supported `InstallModes` array.
- Provide complete `Silent` and `SilentWithProgress` values; WinGet cannot infer or merge them.
- Keep no-reboot arguments in silent fields and mode-independent launch suppression in `Custom`.
- Add logging and install-location switches only when verified.
- Do not copy defaults from MSI, Inno, NSIS, Burn, or a guessed installer family.

## Step-By-Step Analysis

### Step 1: Exhaust Structured Static Detection

Use `Get-WinGetInstallerAnalysis` and [Installer Analysis Workflow](workflow.md). If no parser recognizes the file, record bounded PE, resource, archive, and string evidence without guessing command-line behavior.

### Step 2: Find Matching Publisher Evidence

Use `winget search` to find other accepted packages from the same publisher. Navigate directly to those manifest paths and corresponding Dumplings tasks. Reuse a switch only when the current artifact has the same installer family and configuration; publisher identity alone is insufficient.

### Step 3: Identify Nested Payload And Visible ARP Ownership

Do not infer ARP type from the outer EXE. Route every extracted or downloaded payload through static analysis independently and follow [Installed-State And Association Workflow](installed-state-workflow.md) when the visible owner remains ambiguous.

### Step 4: Determine Architecture, Scope, And Elevation

Use payload architecture and installed executable evidence, not the bootstrapper stub or ARP hive alone. Treat UAC, privilege fallback, and per-user/per-machine behavior as unresolved until static control flow or VM evidence proves them.

### Step 5: Validate Generic Switches One At A Time

When no stronger evidence exists, test `/S`, `/silent`, `/quiet`, `-s`, `--silent`, and `--quiet` individually in a restored VM. Do not combine guesses. Accept a switch only when there is no blocking UI and installed files, visible ARP, scope, and process exit code agree. A zero exit code alone is insufficient.

Unknown EXE families require validation for cancellation, reboot handling, architecture, install location, and downloaded payloads. Specify only `interactive` and `silent` unless a distinct silent-with-progress route is proved.

Block submission when silent installation requires a response file, unavoidable user interaction, or unsupported automation. Before finishing, trace every manifest field to static evidence or a recorded VM result.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for every unproved switch, mode, exit code, scope, elevation route, architecture, payload download, and visible ARP entry. A zero exit code without installed-state evidence is insufficient.

## Implementation Sources

- [Detect It Easy](https://github.com/horsicq/Detect-It-Easy)
- [Universal Extractor 2](https://github.com/Bioruebe/UniExtract2)
