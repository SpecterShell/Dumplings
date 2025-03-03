$Object1 = $Global:DumplingsStorage.ZWSOFTApps.data.Where({ $_.title -eq '中望CAD个人版' }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = (($Object1.download[0].url.Split('/') | Sort-Object -Property { $_.Length } -Bottom 1) -replace '(?<!=)$', '=' | ConvertFrom-Base64) -replace '^\d+' -replace 'https?://dl\.zwsoft\.cn', 'https://upgrade-online.zwsoft.cn'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'V(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.updateDate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      if ($Global:DumplingsStorage.Contains('ZWCADPersonal') -and $Global:DumplingsStorage['ZWCADPersonal'].Contains($this.CurrentState.Version)) {
        # # ReleaseNotes (en-US)
        # $this.CurrentState.Locale += [ordered]@{
        #   Locale = 'en-US'
        #   Key    = 'ReleaseNotes'
        #   Value  = $Global:DumplingsStorage['ZWCADPersonal'][$this.CurrentState.Version].ReleaseNotesEN
        # }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['ZWCADPersonal'][$this.CurrentState.Version].ReleaseNotesCN
        }
      } else {
        # $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
