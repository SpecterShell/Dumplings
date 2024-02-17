# International
$Object1 = Invoke-RestMethod -Uri "https://intl.meeting.huaweicloud.com/v1/usg/tms/softterm/version/query?userType=cloudlink-windows&currentVersion=$($this.LastState.Version ?? '9.7.7')"
if ($Object1.isConsistent) {
  $this.Log("The last version for international edition $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Chinese
$Object2 = Invoke-RestMethod -Uri "https://meeting.huaweicloud.com/v1/usg/tms/softterm/version/query?userType=cloudlink-windows&currentVersion=$($this.LastState.Version ?? '9.7.7')"
if ($Object2.isConsistent) {
  $this.Log("The last version for Chinese edition $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

$Identical = $true
if ($Object1.upgradeVersion -ne $Object2.upgradeVersion) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Object1.upgradeVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.versionPath
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object2.versionPath
}

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.versionDescriptionEn | Format-Text
}
# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object2.versionDescription | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
