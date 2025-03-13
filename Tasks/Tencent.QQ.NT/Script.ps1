$Object1 = Invoke-WebRequest -Uri 'https://im.qq.com/pcqq/index.shtml'
$Object2 = Invoke-RestMethod -Uri ([regex]::Match($Object1.Content, 'rainbowConfigUrl\s*=\s*"(.+?)"').Groups[1].Value) | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.ntDownloadUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.ntDownloadX64Url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object2.ntDownloadARMUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$this.CurrentState.Version = [regex]::Match($Installer.InstallerUrl, '(\d+\.\d+\.\d+_\d+)').Groups[1].Value -replace '_', '.'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.ntPublishTime | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-FileVersionFromExe

    try {
      # Only parse version for major updates
      if (-not $this.Status.Contains('New') -or ($this.CurrentState.Version.Split('.')[0..2] -join '.') -ne ($this.LastState.Version.Split('.')[0..2] -join '.')) {
        $Object3 = Invoke-WebRequest -Uri 'https://im.qq.com/pcqq/support.html'
        $Object4 = Invoke-RestMethod -Uri ([regex]::Match($Object3.Content, 'rainbowConfigUrl\s*=\s*"(.+?)"').Groups[1].Value) | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

        $ReleaseNotesObject = $Object4.ntLogs.Where({ $_.version.EndsWith($Object2.ntVersion) }, 'First')
        if ($ReleaseNotesObject) {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObject[0].features.text | Format-Text
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
