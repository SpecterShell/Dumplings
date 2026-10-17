$Object1 = Invoke-RestMethod -Uri 'https://packages.lithnet.io/manifests/products.json'
$Object2 = Invoke-RestMethod -Uri "https://packages.lithnet.io/$($Object1.Products.Where({ $_.Id -eq 'access-manager' }, 'First')[0].ReleaseLines[0].Components.Where({ $_.Id -eq 'agent' }, 'First')[0].Artifacts.Where({ $_.Id -eq 'agent-win-x64' }, 'First')[0].ManifestPath)/prod.manifest.json.lnk"
$VersionX64 = $Object2.CurrentVersion
$Object3 = Invoke-RestMethod -Uri "https://packages.lithnet.io/$($Object1.Products.Where({ $_.Id -eq 'access-manager' }, 'First')[0].ReleaseLines[0].Components.Where({ $_.Id -eq 'agent' }, 'First')[0].Artifacts.Where({ $_.Id -eq 'agent-win-arm64' }, 'First')[0].ManifestPath)/prod.manifest.json.lnk"
$VersionARM64 = $Object3.CurrentVersion

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionARM64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = "https://packages.lithnet.io/$($Object2.Assets.Where({ $_.Description -eq 'Windows Agent MSI' }, 'First')[0].Uri)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'exe'
  InstallerUrl  = "https://packages.lithnet.io/$($Object3.Assets.Where({ $_.Description -eq 'Windows Agent MSI' }, 'First')[0].Uri)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
