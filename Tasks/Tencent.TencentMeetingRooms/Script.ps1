# x86
$Object1 = Invoke-RestMethod -Uri 'https://meeting.tencent.com/web-service/query-download-info?q=[{"package-type":"rooms","channel":"1410000391","platform":"windows"}]&nonce=AAAAAAAAAAAAAAAA'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://meeting.tencent.com/web-service/query-download-info?q=[{"package-type":"rooms","channel":"1410000391","platform":"windows","arch":"x86_64"}]&nonce=AAAAAAAAAAAAAAAA'

if ($Object1.'info-list'[0].version -ne $Object2.'info-list'[0].version) {
  $this.Log("x86 version: $($Object1.'info-list'[0].version)")
  $this.Log("x64 version: $($Object2.'info-list'[0].version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.'info-list'[0].version

# Installer

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.'info-list'[0].url.Replace('.officialwebsite', '')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.'info-list'[0].url.Replace('.officialwebsite', '')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.'info-list'[0].'sub-date' | Get-Date -Format 'yyyy-MM-dd'
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
