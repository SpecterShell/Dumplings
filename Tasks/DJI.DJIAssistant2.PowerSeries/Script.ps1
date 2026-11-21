$Object1 = Invoke-WebRequest -Uri 'https://www.dji.com/cn/downloads/softwares/dji-assistant-2-power-series' | Read-ResponseContent
$Object2 = $Object1 | Get-EmbeddedJson -StartsFrom '<script type="application/json" id="_SSI_DATA_downloads">' | ConvertFrom-Json -AsHashtable
$Object3 = $Object2.downloads.softwares.data | ForEach-Object { $_.softwares } | Where-Object { $_.slug -eq 'dji-assistant-2-power-series' } | Select-Object -First 1

# Version
$this.CurrentState.Version = $Object3.windows.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object3.windows.links.Where({ $_.category -eq 'exe' }, 'First')[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.windows.release_at

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object3.documents.Where({ $_.category -eq '发布记录' }, 'First')[0].url
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
