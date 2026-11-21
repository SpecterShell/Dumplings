# x64
$Object1 = Invoke-RestMethod -Uri 'https://comate-ide.cdn.bcebos.com/updates/stable/win32/x64/user/latest.json'
# arm64
# $Object2 = Invoke-RestMethod -Uri 'https://comate-ide.cdn.bcebos.com/updates/stable/win32/arm64/user/latest.json'

# if ($Object1.productVersion -ne $Object2.productVersion) {
#   $this.Log("x64 version: $($Object1.productVersion)")
#   $this.Log("arm64 version: $($Object2.productVersion)")
#   throw 'Inconsistent versions detected'
# }

# Version
$this.CurrentState.Version = $Object1.productVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerUrl    = $Object1.url
  InstallerSha256 = $Object1.sha256hash.ToUpper()
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture    = 'arm64'
#   InstallerUrl    = $Object2.url
#   InstallerSha256 = $Object2.sha256hash.ToUpper()
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.timestamp | ConvertFrom-UnixTimeMilliseconds
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
