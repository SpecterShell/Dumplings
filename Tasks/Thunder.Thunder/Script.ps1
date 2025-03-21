# Download
$Object1 = Invoke-RestMethod -Uri 'https://static-xl9-ssl.xunlei.com/json/xl11_official_page.json'
$Version1 = [regex]::Match($Object1.offline, '([\d\.]+)\.exe').Groups[1].Value

# Upgrade
$Object2 = Invoke-RestMethod -Uri 'https://upgrade-pc-ssl.xunlei.com/pc?pid=1&cid=100072&v=11.3.14&os=10&&t=2&lng=0804'

if ($Object2.code -eq 0 -and [Versioning]$Version1 -lt [Versioning]$Object2.data.v) {
  # Version
  $this.CurrentState.Version = $Object2.data.v

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object2.data.url.Replace('upgrade.down.sandai.net', 'down.sandai.net').Replace('up.exe', '.exe')
  }
} else {
  # Version
  $this.CurrentState.Version = $Version1

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object1.offline
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Object2.code -eq 0 -and [Versioning]$Version1 -lt [Versioning]$Object2.data.v) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.data.desc | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
