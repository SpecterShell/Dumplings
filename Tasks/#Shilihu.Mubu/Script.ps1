$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['Mubu'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['Mubu'] = $OldReleases = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri 'https://flomo-resource.oss-cn-shanghai.aliyuncs.com/mubu/update_win.json'

# Version
$this.CurrentState.Version = $Object1.data.real_version_name

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesCN = $Object1.data.whats_new | ConvertFrom-Html | Get-TextContent | Format-Text
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
