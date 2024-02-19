# x86
$Object1 = Invoke-RestMethod -Uri "https://download.flyele.net/v1/downloads/upgrade_version?platform=5&version_number=$($this.LastState.Version ?? '1.8.4')"
# x64
$Object2 = Invoke-RestMethod -Uri "https://download.flyele.net/v1/downloads/upgrade_version?platform=4&version_number=$($this.LastState.Version ?? '1.8.4')"

# Version
$this.CurrentState.Version = $Object2.data.version_number

$Identical = $true
if ($Object1.data.version_number -ne $Object2.data.version_number) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.downloads.full_version.link_url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.data.downloads.full_version.link_url
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object2.data.release_note | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
