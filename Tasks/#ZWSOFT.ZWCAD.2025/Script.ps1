$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['ZWCAD2025'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['ZWCAD2025'] = $OldReleases = [ordered]@{}
}

$Object1 = Invoke-WebRequest -Uri 'https://upgrade-online.zwsoft.cn/zwcad/cad/2025/ZwServerUpdateConfig.xml' | Read-ResponseContent | ConvertFrom-Xml

if ($Object1.ServerConfigs.ZWCAD_X64.'en-US'.version -ne $Object1.ServerConfigs.ZWCAD_X64.'zh-CN'.version) {
  $this.Log("Inconsistent versions: en-US: $($Object1.ServerConfigs.ZWCAD_X64.'en-US'.version), zh-CN: $($Object1.ServerConfigs.ZWCAD_X64.'zh-CN'.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.ServerConfigs.ZWCAD_X64.'zh-CN'.version

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesEN = $Object1.ServerConfigs.ZWCAD_X64.'en-US'.content.Replace('^', "`n") | Format-Text
    }
    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesCN = $Object1.ServerConfigs.ZWCAD_X64.'zh-CN'.content.Replace('^', "`n") | Format-Text
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotesEN = $ReleaseNotesEN
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
