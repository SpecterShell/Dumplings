$Object1 = $Global:DumplingsStorage.AppleProducts
$Object2 = $Object1.Products.GetEnumerator().Where({ $_.Value.Contains('ServerMetadataURL') -and $_.Value.ServerMetadataURL.Contains('WINDOWS64_iCloud.smd') })[-1].Value
$Object3 = Invoke-RestMethod -Uri $Object2.Distributions.English

# Version
$this.CurrentState.Version = $Object3.'installer-gui-script'.choice.'pkg-ref'.Where({ $_.id -eq 'AppleApplicationSupport64' }, 'First')[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.Packages.GetEnumerator().Where({ $_.URL.Contains('AppleApplicationSupport64.msi') }, 'First')[0].URL | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
