$Object1 = Invoke-RestMethod -Uri 'https://api.flydigi.com/web/update/init?app_class_type=13'

# Version
$this.CurrentState.Version = $Object1.data.version_code

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.apk_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.update_time | ConvertFrom-UnixTimeSeconds

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.upgrade_point -replace '\d{4}\.\d{1,2}\.\d{1,2}\s*$' | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
