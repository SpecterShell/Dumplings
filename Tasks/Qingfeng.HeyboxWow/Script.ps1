$Object1 = Invoke-RestMethod -Uri 'https://accoriapi.xiaoheihe.cn/wow/check_new_version_v2/' -Method Post

# Version
$this.CurrentState.Version = $Object1.result.version_list[0].Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.result.version_list[0].DownloadPath
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.result.version_list[0].PublishTime | ConvertFrom-UnixTimeMilliseconds

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = [regex]::Matches($Object1.result.version_list[0].VersionLog, '(?<=<li>).+?(?=</li>)').Value | Format-Text | ConvertTo-UnorderedList
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
