# Dumplings Electron-Builder Automation

## Purpose

Use this routine after static analysis confirms an electron-builder application and an official electron-updater `latest.yml` feed is available. `Adobe.WorkfrontProof` is the standard one-installer template; `7pace.Timetracker` follows the same pattern with a mutable installer filename.

## Feed Discovery

1. Try replacing the installer filename with `latest.yml` in the same directory.
2. If that fails, inspect the embedded `app-*.7z` resources or updater configuration for the feed URL.
3. Fetch only from the official publisher endpoint. Do not substitute a mirror when the feed is temporarily unavailable.
4. Record whether `files[].url` is versioned or mutable, and resolve relative paths against the feed directory.
5. Verify feed `version`, `releaseDate`, `size`, and SHA512 against the selected installer before seeding the task.

## Task Files

Create:

```text
Tasks/<PackageIdentifier>/
  Config.yaml
  Script.ps1
  State.yaml
```

Use this configuration:

```yaml
Type: PackageTask
WinGetIdentifier: Publisher.Package
Skip: false
```

## Script Template

Fetch the feed in the task because request headers, parameters, cookies, retries, or fallback handling are package-specific. Pass the already-fetched text to the converter; the converter itself must not access the network.

`Invoke-RestMethod` returns YAML as plain text because PowerShell does not deserialize YAML automatically:

```powershell
$Prefix = 'https://publisher.example/releases/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-ElectronBuilderUpdateFeed

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Files[0].Url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ReleaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
```

Use `Files[0]` only when the feed has one applicable Windows installer. For multiple architectures, channels, or installer families, inspect every feed entry and map each asset deliberately rather than assuming the first file is correct.

Do not use `ConvertFrom-Yaml` when `ConvertFrom-ElectronBuilderUpdateFeed` already represents the required feed fields. The dedicated converter keeps feed handling consistent and avoids spreading YAML-shape assumptions across tasks.

## Initial State

Seed `State.yaml` from the version already submitted to winget-pkgs so the first routine run is idempotent:

```yaml
Version: 1.2.3
Installer:
- InstallerUrl: https://publisher.example/releases/Product Setup.exe
Locale: []
ReleaseTime: 2026-01-01T12:34:56.0000000Z
```

Use the exact URL representation returned by `Join-Uri`; do not hand-encode it differently in state. Preserve the feed timestamp in UTC. An empty or mismatched initial state can produce a false `New` or `Changed` result and unnecessary logs or submissions.

## Validation

Run the task through the normal model:

```powershell
.\Core\Index.ps1 -Name 'Publisher.Package' -ThrottleLimit 1
```

For a correctly seeded current release, expect no state rewrite, no new `Log_*.yaml`, and no submission. Also run `Invoke-ScriptAnalyzer` on `Script.ps1` and check YAML/whitespace consistency.

If the official feed is temporarily unavailable, retain the official URL and report the live failure. A previously captured, hash-verified feed string may be injected only into an isolated test process to validate parsing, URL resolution, and lifecycle behavior; it must not become a production fallback or be written as an alternate endpoint in the task. Repeat the live test when the publisher endpoint recovers.

## Update Behavior

- `New`, `Changed`, or `Updated`: capture release time, print, and write state/log evidence.
- `Changed` or `Updated`: send the configured notification.
- `Updated`: generate and submit the WinGet manifest update.

Keep package-specific network behavior in the task. Keep feed conversion, NSIS parsing, and reusable URL/YAML mechanics in PackageModule.
