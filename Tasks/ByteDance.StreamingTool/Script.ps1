$Object1 = Invoke-RestMethod -Uri 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=6888137292980951303&uid=&branch=master&buildId='

# Version
$this.CurrentState.Version = $Object1.data.manifest.win32.version

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = $Object1.data.manifest.win32.extra.x86.installerUrl
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data.manifest.win32.extra.x64.installerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = "`"$($Object1.data.releaseNote)`"" | ConvertFrom-Json | Format-Text
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
