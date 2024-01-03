$Object1 = Invoke-RestMethod -Uri 'https://accoriapi.xiaoheihe.cn/wow/check_new_version_v2/' -Method Post

# Version
$this.CurrentState.Version = $Object1.result.version_list[0].Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.result.version_list[0].DownloadPath
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.result.version_list[0].PublishTime | ConvertFrom-UnixTimeMilliseconds

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = [regex]::Matches($Object1.result.version_list[0].VersionLog, '(?<=<li>).+?(?=</li>)').Value | Format-Text | ConvertTo-UnorderedList
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
