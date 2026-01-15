$Object1 = (Invoke-RestMethod -Uri 'https://devtools.wxqcloud.qq.com.cn/WechatWebDev/nightly/versions/config.json').channels.Where({ $_.id -eq 'stable' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.downloads.Where({ $_.os -eq 'Windows' -and $_.arch -eq '32' }, 'First')[0].url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.downloads.Where({ $_.os -eq 'Windows' -and $_.arch -eq '64' }, 'First')[0].url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://developers.weixin.qq.com/miniprogram/dev/devtools/log.html'
      }

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.date | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.description_en | Format-Text
      }

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.description | Format-Text
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
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockWeixinDevTools')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("WeixinDevTools-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["WeixinDevTools-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
    }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()

    if ($ToSubmit) {
      $this.Submit()
    } else {
      $this.Log('Another task is submitting manifests for this package', 'Warning')
    }
  }
}
