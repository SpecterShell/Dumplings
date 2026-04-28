# x64
$Object1 = $Global:DumplingsStorage.DellCatalog | Select-Xml -XPath '/dm:Manifest/dm:SoftwareComponent[./dm:SupportedDevices/dm:Device/@componentID="114288"]' -Namespace @{ dm = $Global:DumplingsStorage.DellCatalog.Manifest.xmlns } | Select-Object -ExpandProperty 'Node' -Last 1
# arm64
$Object2 = $Global:DumplingsStorage.DellCatalog2 | Select-Xml -XPath '/dm:Manifest/dm:SoftwareComponent[./dm:SupportedDevices/dm:Device/@componentID="114670"]' -Namespace @{ dm = $Global:DumplingsStorage.DellCatalog2.Manifest.xmlns } | Select-Object -ExpandProperty 'Node' -Last 1

if ($Object1.vendorVersion -ne $Object2.vendorVersion) {
  $this.Log("x64 version: $($Object1.vendorVersion)")
  $this.Log("arm64 version: $($Object2.vendorVersion)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.vendorVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerUrl    = Join-Uri 'https://dl.dell.com/' $Object1.path
  InstallerSha256 = $Object1.Cryptography.Hash.Where({ $_.algorithm -eq 'SHA256' }, 'First')[0].'#text'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  InstallerUrl    = Join-Uri 'https://dl.dell.com/' $Object2.path
  InstallerSha256 = $Object2.Cryptography.Hash.Where({ $_.algorithm -eq 'SHA256' }, 'First')[0].'#text'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.dateTime | Get-Date -AsUTC

      # # PackageName
      # $this.CurrentState.Locale += [ordered]@{
      #   Key   = 'PackageUrl'
      #   Value = "https://www.dell.com/support/home/drivers/DriversDetails?driverId=$($Object1.releaseID)"
      # }
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'zh-CN'
      #   Key    = 'PackageUrl'
      #   Value  = "https://www.dell.com/support/home/zh-cn/drivers/DriversDetails?driverId=$($Object1.releaseID)"
      # }
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
