# x64 user
$Object1 = Invoke-RestMethod -Uri 'https://center.qoder.sh/algo/api/update/win32-x64-user/stable/latest'
# x64 machine
# $Object2 = Invoke-RestMethod -Uri 'https://center.qoder.sh/algo/api/update/win32-x64/stable/latest'
# arm64 user
# $Object3 = Invoke-RestMethod -Uri 'https://center.qoder.sh/algo/api/update/win32-arm64-user/stable/latest'
# arm64 machine
# $Object4 = Invoke-RestMethod -Uri 'https://center.qoder.sh/algo/api/update/win32-arm64/stable/latest'

# if (@(@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.productVersion } -Unique).Count -gt 1) {
#   $this.Log("Inconsistent versions: x64 user: $($Object1.productVersion), x64 machine: $($Object2.productVersion), arm64 user: $($Object3.productVersion), arm64 machine: $($Object4.productVersion)", 'Error')
#   return
# }

# Version
$this.CurrentState.Version = $Object1.productVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object1.url
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x64'
#   Scope        = 'machine'
#   InstallerUrl = $Object2.url
# }
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm64'
#   Scope        = 'user'
#   InstallerUrl = $Object3.url
# }
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm64'
#   Scope        = 'machine'
#   InstallerUrl = $Object4.url
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

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
