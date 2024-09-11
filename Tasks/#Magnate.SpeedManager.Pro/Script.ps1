$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['SpeedManagerPro'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['SpeedManagerPro'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = Invoke-WebRequest -Uri 'https://file2.speedtest.cn/pc-pro/win64/version.json' | Read-ResponseContent | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.version

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesCN = ($Object1.describe | ConvertFrom-Html | Get-TextContent) -replace '(?m)^-\s*' | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotesCN = $ReleaseNotesCN
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
}
