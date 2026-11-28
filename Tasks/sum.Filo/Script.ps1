# The site publishes the version only in this plain-text sidecar, which the app's own updater
# (electron/update.ts) reads before fetching a versioned URL of its own. That versioned URL lives
# on an OSS bucket domain (flowsrun.oss-cn-beijing.aliyuncs.com), which winget-pkgs sends to manual
# review, so the installer is taken from the vendor's own download URL and checked against the
# SHA-256 the vendor publishes beside it.
$AssetName = 'Filo-Setup-x64.exe'
$InstallerUrl = "https://filoapp.dev/download/$AssetName"
$VersionUrl = "https://filoapp.dev/download/$AssetName.version"
$Sha256Url = "https://filoapp.dev/download/$AssetName.sha256"

# Version
$this.CurrentState.Version = (Invoke-WebRequest -Uri $VersionUrl | Read-ResponseContent).Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $InstallerUrl
}

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The version endpoint does not provide a numeric version.'
}
if ($this.CurrentState.Installer[0].InstallerUrl -notmatch '^https://filoapp\.dev/download/Filo-Setup-x64\.exe$') {
  throw 'The download URL does not resolve to the Windows setup installer.'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $ExpectedSha256 = ((Invoke-WebRequest -Uri $Sha256Url | Read-ResponseContent).Trim() -split '\s+')[0]
    $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl
    if ((Get-FileHash -LiteralPath $InstallerFile -Algorithm SHA256).Hash -ine $ExpectedSha256) {
      throw 'The downloaded installer does not match the SHA-256 published by filoapp.dev.'
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
