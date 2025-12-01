$Object1 = Invoke-WebRequest -Uri 'https://servicewechat.com/wxa-dev-logic/checkupdate?force=1' | Read-ResponseContent | ConvertFrom-Json

# Version
$VersionLength = $Object1.update_version.ToString().Length
$this.CurrentState.Version = $Object1.update_version.ToString().Insert($VersionLength - 7, '.').Insert($VersionLength - 9, '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = (Get-RedirectedUrl -Uri "https://servicewechat.com/wxa-dev-logic/download_redirect?os=win&type=ia32&download_version=$($Object1.update_version)&version_type=1&pack_type=0").Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = (Get-RedirectedUrl -Uri "https://servicewechat.com/wxa-dev-logic/download_redirect?os=win&type=x64&download_version=$($Object1.update_version)&version_type=1&pack_type=0").Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($this.CurrentState.Version.Split('.')[2].SubString(0, 6), 'yyMMdd', $null).ToString('yyyy-MM-dd')

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.changelog_desc | Format-Text
      }

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.changelog_url
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
