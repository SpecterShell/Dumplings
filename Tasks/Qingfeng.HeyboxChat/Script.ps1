# x86
$Object1 = Invoke-RestMethod -Uri 'https://chat.xiaoheihe.cn/chatroom/settings/get_history_version?os_type=web&version=999.0.4&x_os_type=Windows&type=32&hkey=S2UYS97&_time=1&nonce=1'
$VersionX86 = $Object1.result.list[0].version
# x64
$Object2 = Invoke-RestMethod -Uri 'https://chat.xiaoheihe.cn/chatroom/settings/get_history_version?os_type=web&version=999.0.4&x_os_type=Windows&type=64&hkey=S2UYS97&_time=1&nonce=1'
$VersionX64 = $Object2.result.list[0].version

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.result.list[0].download_url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.result.list[0].download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.result.list[0].publish_time | ConvertFrom-UnixTimeSeconds

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.result.list[0].version_content | ConvertFrom-Html | Get-TextContent | Format-Text
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
