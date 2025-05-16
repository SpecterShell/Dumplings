$Prefix = 'https://releases.mattermost.com/desktop/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'nullsoft'
  InstallerUrl  = Join-Uri $Prefix $Object1.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = (Join-Uri $Prefix $Object1.files[0].url) -replace '-setup' -replace '\.exe$', '-x64.msi'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = (Join-Uri $Prefix $Object1.files[0].url) -replace '-setup' -replace '\.exe$', '-arm64.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
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
