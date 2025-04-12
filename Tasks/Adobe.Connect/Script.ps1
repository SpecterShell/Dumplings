$Object1 = Invoke-RestMethod -Uri "https://my.adobeconnect.com/common/UpdateDescr.xml?noCache=$(Get-Random)"

# if ($Object1.UpdateDescr.Windows.Release[0].Version -ne $Object1.UpdateDescr.Win32.Release[0].Version) {
#   $this.Log("x86 version: $($Object1.UpdateDescr.Win32.Release[0].Version)")
#   $this.Log("x64 version: $($Object1.UpdateDescr.Windows.Release[0].Version)")
#   throw 'Inconsistent versions detected'
# }

# Version
$this.CurrentState.Version = $Object1.UpdateDescr.Windows.Release[0].Version

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture           = 'x86'
#   InstallerType          = 'exe'
#   InstallerUrl           = Get-RedirectedUrls -Uri 'https://www.adobe.com/go/Connect11_32AppStandalone' -Method GET | Select-Object -Last 1
#   AppsAndFeaturesEntries = @(
#     [ordered]@{
#       DisplayVersion = "$($this.CurrentState.Version).32"
#     }
#   )
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerType          = 'exe'
  InstallerUrl           = Get-RedirectedUrls -Uri 'https://www.adobe.com/go/Connect11AppStandalone' -Method GET | Select-Object -Last 1
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = "$($this.CurrentState.Version).64"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.UpdateDescr.Windows.Release[0].ReleaseDate | Get-Date -Format 'yyyy-MM-dd'
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
