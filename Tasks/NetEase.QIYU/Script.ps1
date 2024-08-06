$Object1 = ((Invoke-WebRequest -Uri 'https://b.163.com/home/download').Content | Get-EmbeddedJson -StartsFrom 'window._wInitData =' | ConvertFrom-Json -AsHashtable).appInfo.routeConf.schema.body.Where({ $_.Contains('detail') }, 'First')[0].detail.pcWorkstation

# Version
$this.CurrentState.Version = $Version = $Object1.version -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.app
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.updateTime | Get-Date -Format 'yyyy-MM-dd'

      if ($Global:DumplingsStorage.Contains('QIYU') -and $Global:DumplingsStorage['QIYU'].Contains($Version)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['QIYU'].$Version.ReleaseNotesCN
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
