# x64
$Object1 = (Invoke-RestMethod -Uri 'https://releases.talon-sec.com/api/v1/appcast.xml?appid={dfef2477-4f0e-454b-bc0d-03ce61074e4c}&platform=win&architecture=x64&channel=packaged')[-1]
# arm64
$Object2 = (Invoke-RestMethod -Uri 'https://releases.talon-sec.com/api/v1/appcast.xml?appid={dfef2477-4f0e-454b-bc0d-03ce61074e4c}&platform=win&architecture=arm64&channel=packaged')[-1]

if ($Object1.enclosure.shortVersionString -ne $Object2.enclosure.shortVersionString) {
  $this.Log("Inconsistent versions: x64: $($Object1.enclosure.shortVersionString), arm64: $($Object2.enclosure.shortVersionString)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object2.enclosure.shortVersionString

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.enclosure.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object2.enclosure.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.pubDate | Get-Date -AsUTC
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
