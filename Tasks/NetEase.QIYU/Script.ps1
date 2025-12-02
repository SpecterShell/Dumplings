$Object1 = Invoke-RestMethod -Uri 'https://qiyukf.com/download/getDownloadInfoV2?type=pcWorkstation'

# Version
$this.CurrentState.Version = $Object1.result.pcWorkstation.version -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  # InstallerUrl = $Object1.result.pcWorkstation.app
  InstallerUrl = "https://ysf.qiyukf.net/QIYU_PC_Setup_$($Object1.result.pcWorkstation.version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.result.pcWorkstation.updateTime | Get-Date -Format 'yyyy-MM-dd'

      if ($Global:DumplingsStorage.Contains('QIYU') -and $Global:DumplingsStorage.QIYU.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.QIYU[$this.CurrentState.Version].ReleaseNotesCN
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
