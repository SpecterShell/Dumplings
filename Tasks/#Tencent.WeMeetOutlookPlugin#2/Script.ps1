$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['WeMeetOutlookPlugin2'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['WeMeetOutlookPlugin2'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri "https://meeting.tencent.com/web-service/query-app-plugin-update-info/?platform=windows&channel=0300000000&pluginuid=plugin_876be383ea1c01576b2676d34d75f9a6&nonce=AAAAAAAAAAAAAAAA&plugin-ver=$($this.LastState.Version ?? '1.2.0.0')"

if ($null -eq $Object1.target) {
  $this.Log("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.target.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.target.url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesCN = $Object1.target.features_description | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      InstallerUrl   = $InstallerUrl
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
