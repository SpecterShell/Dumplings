# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Global:DumplingsStorage.QQApps.ntDownloadUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$VersionX86 = [regex]::Match($InstallerX86.InstallerUrl, '(\d+\.\d+\.\d+_\d+)').Groups[1].Value -replace '_', '.'

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Global:DumplingsStorage.QQApps.ntDownloadX64Url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+\.\d+\.\d+_\d+)').Groups[1].Value -replace '_', '.'

$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Global:DumplingsStorage.QQApps.ntDownloadARMUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$VersionARM64 = [regex]::Match($InstallerARM64.InstallerUrl, '(\d+\.\d+\.\d+_\d+)').Groups[1].Value -replace '_', '.'

if (@(@($VersionX86, $VersionX64, $VersionARM64) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  $this.Log("arm64 version: ${VersionARM64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

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
