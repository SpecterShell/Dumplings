$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['360Zip'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['360Zip'] = $OldReleases = [ordered]@{}
}

$Path = Get-TempFile -Uri 'https://iup.360safe.com/iv3/pc/360zip/360zipupd_manual.cab'
expand.exe -R $Path | Out-Host
$Object1 = Join-Path $Path '..' '360zipupd_manual.ini' -Resolve | Get-Item | Get-Content -Raw -Encoding 'gb18030' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.'360App1'.ver

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $ReleaseTime = $Object1.'360App1'.date | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesCN = $Object1.'360App1'.'tip_zh-CN' | Format-Text
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime    = $ReleaseTime
      ReleaseNotesCN = $ReleaseNotesCN
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleases | ConvertTo-Yaml -OutFile $OldReleasesPath -Force
    }
  }
  'New' {
    $this.Print()
    $this.Write()
  }
  { $_ -match 'Changed' -and $_ -notmatch 'Updated|Rollbacked' } {
    $this.Print()
    $this.Write()
    $this.Message()
  }
  'Updated' {
    $this.Print()
    $this.Write()
    if (-not $OldReleases.Contains($this.CurrentState.Version)) {
      $this.Message()
    }
  }
  { $_ -match 'Rollbacked' -and -not $OldReleases.Contains($this.CurrentState.Version) } {
    $this.Print()
    $this.Message()
  }
}
