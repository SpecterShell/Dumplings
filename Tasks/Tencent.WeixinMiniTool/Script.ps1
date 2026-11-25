$Object1 = Invoke-RestMethod -Uri 'https://devtools.wxqcloud.qq.com.cn/WechatWebDev/minitool/versions/history_minitool.js' | Get-EmbeddedJson -StartsFrom '(' | ConvertFrom-Json
$Object2 = $Object1.history[0]

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object2.downloads.Where({ $_.os -eq 'Windows' -and $_.arch -eq '64' }, 'First')[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.date | Get-Date -Format 'yyyy-MM-dd'
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
