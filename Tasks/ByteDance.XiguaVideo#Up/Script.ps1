$Object1 = Invoke-RestMethod -Uri 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=6922326164589517070&branch=master&buildId=&uid='

# Version
$this.CurrentState.Version = $Object1.data.manifest.win32.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.manifest.win32.urls[0] | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.manifest.win32.extra.uploadDate | ConvertFrom-UnixTimeMilliseconds

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.releaseNote | Format-Text
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
