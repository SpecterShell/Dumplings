# Download
$Object1 = Invoke-RestMethod -Uri 'https://static-xl.a.88cdn.com/json/xunlei_video_version_pc.json'
# Upgrade
$Object2 = Invoke-RestMethod -Uri 'http://upgrade.xl9.xunlei.com/pc?pid=2&cid=100039&v=6.2.3.580&os=10&t=2&lng=0804'

if ($Object2.code -eq 0 -and [Versioning.Versioning]$Object1.version -lt [Versioning.Versioning]$Object2.data.v) {
  # Version
  $this.CurrentState.Version = $Object2.data.v

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object2.data.url.Replace('xmpup', 'xmp')
  }
} else {
  # Version
  $this.CurrentState.Version = $Object1.version

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object1.url | ConvertTo-Https
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Object2.code -eq 0 -and [Versioning.Versioning]$Object1.version -lt [Versioning.Versioning]$Object2.data.v) {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.data.desc | Format-Text
        }
      } else {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object1.update_time | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object1.content | Format-Text
        }
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
