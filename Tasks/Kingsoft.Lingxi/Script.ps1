$Object1 = Invoke-RestMethod -Uri 'https://www.kdocs.cn/kdg/api/v1/params/MusaConfig'

# Version
$this.CurrentState.Version = $Object1.data.'download-url'.platforms.windows.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.'download-url'.platforms.windows.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.'download-url'.changeLog.更新点 | ConvertTo-UnorderedList | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Prefix = $Object1.data.'download-url'.hotUpdateUrl.win
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
