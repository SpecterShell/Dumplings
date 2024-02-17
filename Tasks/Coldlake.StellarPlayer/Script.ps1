$Object1 = (Invoke-RestMethod -Uri 'https://api.stellarplayer.com/v1/cfg/getConfig?cfgKey=nZngW7WDWeVxm').data.cfgInfo.nZngW7WDWeVxm.cfgDetail | ConvertFrom-Json

# Version
$this.CurrentState.Version = [regex]::Match($Object1.filename, '(\d{14})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.offical_http_address
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
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

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsStellarPlayer')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $LocalStorage.Contains("StellarPlayerSubmitting-$($this.CurrentState.Version)")) {
      $LocalStorage["StellarPlayerSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
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
