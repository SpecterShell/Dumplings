$Object1 = Invoke-RestMethod -Uri 'https://web.qingtui.com/api/client/web/update' -Headers @{
  CLIENT = "QingTui/$($this.Status.Contains('New') ? '70002' : $this.LastState.Version);Windows NT 10.0, WOW64;PC;0"
}

# Version
$this.CurrentState.Version = $Object1.data.webVersions.Where({ $_.type -eq 'winpc' })[0].lastestVer

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.webVersions.Where({ $_.type -eq 'winpc' })[0].lastestVerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.webVersions.Where({ $_.type -eq 'winpc' })[0].lastestVerNote | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
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
