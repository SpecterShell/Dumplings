# Unity Hub — winget update task for SpecterShell/Dumplings.
#
# Discovers the current GA version from Unity Hub's electron-updater feed and
# submits the immutable, version-pinned x64 installer URL. This mirrors the
# Unity Editor tasks, which discover versions from a feed rather than from
# installer-hash changes, so it works with pinned URLs (pinned URLs are what
# keep older winget versions from being auto-deleted).
$FeedBase = 'https://public-cdn.cloud.unity3d.com/hub/prod'

# Version — latest.yml (the GA channel's electron-updater feed) carries the
# current GA version.
$Version = (Invoke-RestMethod -Uri "${FeedBase}/latest.yml" | ConvertFrom-Yaml).version
$this.CurrentState.Version = $Version

# Installer — build the immutable, version-pinned URL deterministically from the
# version, matching the published layout (<base>/<version>/<file>) and the
# installer file name. This intentionally does NOT reuse latest.yml's own file
# paths, so the submitted URL stays pinned even if the feed ever points at the
# rolling alias. x64 only: Unity Hub's Windows arm64 installer currently trips
# winget's `Validation-Defender-Error` in the install test.
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${FeedBase}/${Version}/UnityHubSetup-${Version}-x64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
