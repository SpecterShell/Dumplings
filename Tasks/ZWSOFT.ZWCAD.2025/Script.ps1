$Object1 = $Global:DumplingsStorage.ZWSOFTApps.data.Where({ $_.title -eq '中望CAD 2025' }, 'First')[0]
$Object2 = Invoke-WebRequest -Uri $Object1.download[0].url

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://upgrade-online.zwsoft.cn' ([regex]::Match($Object2.Content, 'https://download\.zwsoft\.cn/\d+/[a-zA-Z0-9]+([^"]+)').Groups[1].Value)
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'Release(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.updateDate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      if ($Global:DumplingsStorage.Contains('ZWCAD2025') -and $Global:DumplingsStorage['ZWCAD2025'].Contains($this.CurrentState.RealVersion)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['ZWCAD2025'][$this.CurrentState.RealVersion].ReleaseNotesEN
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['ZWCAD2025'][$this.CurrentState.RealVersion].ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
