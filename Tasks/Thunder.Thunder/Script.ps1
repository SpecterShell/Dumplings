# Download
$Object1 = Invoke-RestMethod -Uri 'https://static-xl9-ssl.xunlei.com/json/xl11_official_page.json'
$Version1 = [regex]::Match($Object1.offline, '([\d\.]+)\.exe').Groups[1].Value

# Upgrade
$Object2 = Invoke-RestMethod -Uri 'https://upgrade-pc-ssl.xunlei.com/pc?pid=1&cid=100072&v=11.3.14&os=10&&t=2&lng=0804'

if ($Object2.code -eq 0 -and (Compare-Version -ReferenceVersion $Version1 -DifferenceVersion $Object2.data.v) -gt 0) {
  # Version
  $Task.CurrentState.Version = $Object2.data.v

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object2.data.url.Replace('upgrade.down.sandai.net', 'down.sandai.net').Replace('up.exe', '.exe')
  }

  # ReleaseNotes (zh-CN)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object2.data.desc | Format-Text
  }
} else {
  # Version
  $Task.CurrentState.Version = $Version1

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object1.offline
  }
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
