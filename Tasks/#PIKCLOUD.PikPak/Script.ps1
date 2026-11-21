$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['PikPak'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['PikPak'] = $OldReleases = [ordered]@{}
}

# en-US
$Object1 = Invoke-RestMethod -Uri 'https://config.mypikpak.com/config/v1/client_version' -Method Post -Body (
  @{
    data   = @{ language = 'en-US' }
    client = 'windows'
  } | ConvertTo-Json -Compress
)
# zh-CN
$Object2 = Invoke-RestMethod -Uri 'https://config.mypikpak.com/config/v1/client_version' -Method Post -Body (
  @{
    data   = @{ language = 'zh-CN' }
    client = 'windows'
  } | ConvertTo-Json -Compress
)

# Version
$this.CurrentState.Version = $Object1.values.client_version.newVersionName

# RealVersion
$this.CurrentState.RealVersion = $Object1.values.client_version.newVersionName.Split('.')[0..2] -join '.'

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes = $Object1.values.client_version.news | Format-Text
    }

    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesCN = $Object2.values.client_version.news | Format-Text
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
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
