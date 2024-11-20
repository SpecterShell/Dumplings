$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['SpeedManager'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['SpeedManager'] = $OldReleases = [ordered]@{}
}

$Object1 = Invoke-WebRequest -Uri 'https://file2.speedtest.cn/pc/win64/version.json' | Read-ResponseContent | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.version

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesCN = ($Object1.describe | ConvertFrom-Html | Get-TextContent) -replace '(?m)^-\s*' | Format-Text
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotesCN = $ReleaseNotesCN
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleases | ConvertTo-Yaml -OutFile $OldReleasesPath -Force
    }

    $this.Print()
    $this.Write()
  }
  { $_ -match 'Changed' -and $_ -notmatch 'Updated|Rollbacked' } {
    $this.Message()
  }
  { $_ -match 'Updated|Rollbacked' -and -not $OldReleases.Contains($this.CurrentState.Version) } {
    $this.Message()
  }
}
