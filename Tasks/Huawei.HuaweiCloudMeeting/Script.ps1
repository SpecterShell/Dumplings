# Global
$Object1 = Invoke-RestMethod -Uri "https://intl.meeting.huaweicloud.com/v1/usg/tms/softterm/version/query?userType=cloudlink-windows&currentVersion=$($this.LastState.Version ?? '9.7.7')"
if ($Object1.isConsistent) {
  $this.Log("The version for the global edition from the last state $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# China
$Object2 = Invoke-RestMethod -Uri "https://meeting.huaweicloud.com/v1/usg/tms/softterm/version/query?userType=cloudlink-windows&currentVersion=$($this.LastState.Version ?? '9.7.7')"
if ($Object2.isConsistent) {
  $this.Log("The version for the China edition from the last state $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

if ($Object1.upgradeVersion -ne $Object2.upgradeVersion) {
  $this.Log("Global version: $($Object1.upgradeVersion)")
  $this.Log("China version: $($Object2.upgradeVersion)")
  throw 'Inconsistent versions detected'
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

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
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
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
