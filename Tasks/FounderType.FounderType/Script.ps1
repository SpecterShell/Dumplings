$Object1 = Invoke-RestMethod -Uri 'https://fclient.foundertype.com/version' -Method Post -Body @{
  browser_version = ''
  is_x86          = '0'
  mac             = ''
  platform        = 'fz_windows'
  source_type     = ''
  system          = ''
  tag             = '121'
  version         = ''
  secret          = $DumplingsSecret.FounderTypeSecret
}

# Version
$this.CurrentState.Version = $Object1.founder_data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $Object1.founder_data.upgrade_url "/fclient/pro/windows/$($this.CurrentState.Version)/FounderClient_x86_$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Object1.founder_data.upgrade_url "/fclient/pro/windows/$($this.CurrentState.Version)/FounderClient_$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.founder_data.content | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri (Join-Uri $Object1.founder_data.upgrade_url 'latest.yml') | ConvertFrom-Yaml

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
