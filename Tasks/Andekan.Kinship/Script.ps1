$Object1 = Invoke-RestMethod -Uri 'https://app.kinship.io/index.php?action=download_addin&func=get_assets&version=release'
# EXE
$Object2 = $Object1.Where({ $_.id -eq '230629220' }, 'First')[0]
# MSI
$Object3 = $Object1.Where({ $_.id -eq '230629257' }, 'First')[0]

if ($Object2.version -ne $Object3.version) {
  $this.Log("EXE version: $($Object2.version)")
  $this.Log("MSI version: $($Object3.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType   = 'inno'
  InstallerUrl    = "https://app.kinship.io/download/$($Object2.fileNameNoVer)-$($Object2.version).exe"
  InstallerSha256 = $Object2.SHA256
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType   = 'msi'
  InstallerUrl    = "https://app.kinship.io/download/$($Object3.fileNameNoVer)-$($Object3.version).msi"
  # InstallerSha256 = $Object3.SHA256
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.date.ToUniversalTime()
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
