# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Global:DumplingsStorage.QQApps.downloadUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

if ($this.CurrentState.Installer[0].InstallerUrl -notmatch '\d+\.\d+\.\d+.\d{6}') {
  $this.Log('The version does not contain 6-digits build number', 'Info')
  return
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+\.\d+\.\d+.\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.QQApps.updateDate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-FileVersionFromExe

    try {
      # Only parse version for major updates
      if (-not $this.Status.Contains('New') -or ($this.CurrentState.Version.Split('.')[0..2] -join '.') -ne ($this.LastState.Version.Split('.')[0..2] -join '.')) {
        $Object3 = Invoke-WebRequest -Uri 'https://im.qq.com/pcqq/support.html'
        $Object4 = Invoke-RestMethod -Uri ('https:' + [regex]::Match($Object3.Content, 'rainbowConfigUrl\s*=\s*"(.+?)"').Groups[1].Value) | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

        $ReleaseNotesObject = $Object4.log.Where({ $_.version.EndsWith($Global:DumplingsStorage.QQApps.version) }, 'First')
        if ($ReleaseNotesObject) {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObject[0].feature | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
