$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['Lattics'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['Lattics'] = $OldReleases = [ordered]@{}
}

# Global
$Object1 = Invoke-RestMethod -Uri 'https://itunes.apple.com/lookup?id=1575605022&country=US&lang=en_us'
# China
$Object2 = Invoke-RestMethod -Uri 'https://itunes.apple.com/lookup?id=1575605022&country=CN&lang=zh_cn'

$ResultGlobal = @($Object1.results)
$ResultChina = @($Object2.results)
if ($ResultGlobal.Count -eq 0) {
  $this.Log('The Global iTunes lookup returned no result', 'Error')
  return
}
if ($ResultChina.Count -eq 0) {
  # The app is no longer listed on the China storefront, so only Global is comparable
  $this.Log('The China iTunes lookup returned no result; using the Global version only', 'Warning')
} elseif ($ResultGlobal[0].version -ne $ResultChina[0].version) {
  $this.Log("Inconsistent versions: Global: $($ResultGlobal[0].version), China: $($ResultChina[0].version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $ResultGlobal[0].version

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $ReleaseTime = $ResultGlobal[0].currentVersionReleaseDate.ToUniversalTime()

    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes = $ResultGlobal[0].releaseNotes | Format-Text
    }
    # ReleaseNotes (zh-CN)
    $ReleaseNotesCN = $ResultChina.Count -gt 0 ? ($ResultChina[0].releaseNotes | Format-Text) : ''
    if ($ReleaseNotesCN) {
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesCN
      }
    } else {
      $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime    = $ReleaseTime
      ReleaseNotes   = $ReleaseNotes
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
