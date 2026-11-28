# The site publishes no version anywhere except this plain-text sidecar, which the app's own
# updater (electron/update.ts) reads before fetching `${mirror}/v${version}/${asset}`.
$AssetName = 'Filo-Setup-x64.exe'
$VersionUrl = "https://filoapp.dev/download/$AssetName.version"
$Sha256Url = "https://filoapp.dev/download/$AssetName.sha256"
$MirrorRoot = 'https://flowsrun.oss-cn-beijing.aliyuncs.com/filo'

# Version
$this.CurrentState.Version = (Invoke-WebRequest -Uri $VersionUrl | Read-ResponseContent).Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = "$MirrorRoot/v$($this.CurrentState.Version)/$AssetName"
}

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The version endpoint does not provide a numeric version.'
}
if ($this.CurrentState.Installer[0].InstallerUrl -notmatch '/v[0-9.]+/Filo-Setup-x64\.exe$') {
  throw 'The versioned mirror URL does not resolve to the Windows setup installer.'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $ExpectedSha256 = ((Invoke-WebRequest -Uri $Sha256Url | Read-ResponseContent).Trim() -split '\s+')[0]
    $InstallerUrl = [string]$this.CurrentState.Installer[0].InstallerUrl
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
