$Object1 = Invoke-RestMethod -Uri "https://mesh.if.iqiyi.com/player/client/version/update?version=$($this.LastState.Contains('Version') ? $this.LastState.Version : '12.4.5.8126')&system=x64"

# Version
$this.CurrentState.Version = $Object1.data.update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://mesh.if.iqiyi.com/player/upgrade/file/$($this.CurrentState.Version)/IQIYIsetup_winget.exe"
  # InstallerUrl = $Object1.data.update.cubelink
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.update.verinfo.Split('$$$$') | Format-Text
      }
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
