$Object1 = Invoke-RestMethod -Uri 'https://upgrade-pc-ssl.xunlei.com/pc' -Body @{
  v   = $this.Status.Contains('New') ? '12.1.2' : $this.LastState.Version
  os  = '10'
  t   = '2'
  lng = '0804'
}

if ($Object1.code -ne 0) {
  $this.Log($Object1.content, 'Warning')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.v

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.url.Replace('upgrade.down.sandai.net', 'down.sandai.net').Replace('up.exe', '.exe')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.desc | Format-Text
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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockThunder')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("Thunder-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["Thunder-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
