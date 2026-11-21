$Object1 = Invoke-RestMethod -Uri 'https://kev.kuaishou.com/kev/release/checkUpdate' -Method Post -Body (
  @{
    platform  = 'win32'
    arch      = 'x64'
    osRelease = '10.0.22000'
    version   = $this.Status.Contains('New') ? '1.3.27' : $this.LastState.Version
    appId     = '7DzYAECbUK'
  }
)

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Prefix = $Object1.versionPath

      $Object2 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.releaseDate | Get-Date -AsUTC
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
