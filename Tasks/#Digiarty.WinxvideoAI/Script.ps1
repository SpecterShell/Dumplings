$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['DigiartyWinxvideoAI'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['DigiartyWinxvideoAI'] = $OldReleases = [ordered]@{}
}

# Version and release date
$Object1 = Invoke-RestMethod -Uri 'https://www.winxdvd.com/winxvideo-ai/upgrade/version-update.json'

# Localized upgrade logs (the Simplified Chinese feed carries a UTF-8 BOM)
$Object2 = (Invoke-WebRequest -Uri $Object1.en).Content.TrimStart([char]0xFEFF) | ConvertFrom-Json
$Object3 = (Invoke-WebRequest -Uri $Object1.'zh-hans').Content.TrimStart([char]0xFEFF) | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.version

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $Object1.date

    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes = ($Object2.upgrade.upgradelog -join "`n") -replace '#new#', $this.CurrentState.Version | ConvertFrom-Html | Get-TextContent | Format-Text
    }

    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesCN = ($Object3.upgrade.upgradelog -join "`n") -replace '#new#', $this.CurrentState.Version | ConvertFrom-Html | Get-TextContent | Format-Text
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime    = $this.CurrentState.ReleaseTime
      ReleaseNotesEn = $ReleaseNotes
      ReleaseNotesZh = $ReleaseNotesCN
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
