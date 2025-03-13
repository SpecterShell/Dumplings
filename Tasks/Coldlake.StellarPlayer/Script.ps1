$Object1 = (Invoke-RestMethod -Uri 'https://api.stellarplayer.com/v1/cfg/getConfig?cfgKey=nZngW7WDWeVxm').data.cfgInfo.nZngW7WDWeVxm.cfgDetail | ConvertFrom-Json

# Version
$this.CurrentState.Version = [regex]::Match($Object1.filename, '(\d{14})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.offical_http_address
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri "https://player-update.coldlake1.com/version/gray/$($this.CurrentState.Version)_x64.ini" | Read-ResponseContent | ConvertFrom-Ini

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.update.info | Format-Text
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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsStellarPlayer')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("StellarPlayerSubmitting-$($this.CurrentState.Version)")) {
      $Global:DumplingsStorage["StellarPlayerSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
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
