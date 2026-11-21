$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['VooVMeeting2'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['VooVMeeting2'] = $OldReleases = [ordered]@{}
}

# x86
$Object1 = Invoke-RestMethod -Uri "https://voovmeeting.com/web-service/query-app-update-info/?os=Windows&app_publish_channel=Overseas&sdk_id=1410000197&from=2&appver=$($this.Status.Contains('New') ? '3.20.3.520' : $this.LastState.Version)"
# x64
# $Object2 = Invoke-RestMethod -Uri "https://voovmeeting.com/web-service/query-app-update-info/?os=Windows&app_publish_channel=Overseas&sdk_id=1410000197&from=2&appver=$($this.Status.Contains('New') ? '3.20.3.520' : $this.LastState.Version)&arch=x86_64"

if ($Object1.upgrade_policy -eq 0) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# if ($Object1.version -ne $Object2.version) {
#   $this.Log("Inconsistent versions: x86: $($Object1.version), x64: $($Object2.version)", 'Error')
#   return
# }

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl = $Object1.package_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x64'
#   InstallerUrl = $InstallerUrlX64 = $Object2.package_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesCN = $Object1.features_description | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      InstallerUrl    = $InstallerUrl
      # InstallerUrlX64 = $InstallerUrlX64
      ReleaseNotesCN  = $ReleaseNotesCN
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
