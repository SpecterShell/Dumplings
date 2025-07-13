$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['RevoScan'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['RevoScan'] = $OldReleases = [ordered]@{}
}

# en-US
$Object1 = Invoke-RestMethod -Uri 'https://api.infly3d.com/software/version/info' -Method Post -Body (
  @{
    deploy                = 'test'
    sn_code               = 'FFFFFFFFFFFFFF051'
    # The version here should have 4 parts, e.g. v5.4.12.1526, but the version returned by the endpoint only has 3 parts, e.g. v5.4.12
    # Use the 3-parts version anyway
    user_version_string   = $this.Status.Contains('New') ? 'v5.4.12.1526' : "v$($this.LastState.Version)"
    version_desc_language = 'en_US'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

if ($Object1.code -eq 1000) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}
if ($Object1.code -ne 200) { throw $Object1.msg }

$VersionEN = $Object1.data.target_version -replace '^v'

# zh-CN
$Object2 = Invoke-RestMethod -Uri 'https://api.infly3d.com/software/version/info' -Method Post -Body (
  @{
    deploy                = 'test'
    sn_code               = 'FFFFFFFFFFFFFF051'
    user_version_string   = $this.Status.Contains('New') ? 'v5.4.12.1526' : "v$($this.LastState.Version)"
    version_desc_language = 'zh_CN'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

if ($Object2.code -eq 1000) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}
if ($Object2.code -ne 200) { throw $Object2.msg }

$VersionCN = $Object2.data.target_version -replace '^v'

if ($VersionEN -ne $VersionCN) {
  $this.Log("Inconsistent versions: en-US: ${VersionEN}, zh-CN: ${VersionCN}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionEN

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes = $Object1.data.version_desc | Format-Text
    }
    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesCN = $Object2.data.version_desc | Format-Text
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
