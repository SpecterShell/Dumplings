# Global
$Object1 = Invoke-RestMethod -Uri 'https://www.scholaread.com/api/configs/version'
# China
$Object2 = Invoke-RestMethod -Uri 'https://www.scholaread.cn/api/configs/version'

if ($Object1.data.pc.the_latest_version -ne $Object2.data.pc_cn.the_latest_version) {
  $this.Log("Global version: $($Object1.data.pc.the_latest_version)")
  $this.Log("China version: $($Object2.data.pc_cn.the_latest_version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.data.pc.the_latest_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Object1.data.pc.feed_url "Scholaread-win-x64-$($Object1.data.pc.the_latest_version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = Join-Uri $Object2.data.pc_cn.feed_url "Scholaread-win-x64-$($Object2.data.pc_cn.the_latest_version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.pc.version_info | Format-Text
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.data.pc_cn.version_info | Format-Text
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
