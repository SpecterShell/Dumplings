$Object1 = Invoke-WebRequest -Uri 'https://im.dingtalk.com/manifest/x64/release_windows_vista_later_all.json' | Read-ResponseContent | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.win.package.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.win.install.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      try {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($Object1.win.install.description[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.win.install.multi_lang_description.en_US | Select-Object -Skip 1 | Format-Text
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object1.win.install.description | Select-Object -Skip 1 | Format-Text
        }
      } catch {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.win.install.multi_lang_description.en_US | Format-Text
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object1.win.install.description | Format-Text
        }
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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockDingTalk')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("DingTalk-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["DingTalk-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
