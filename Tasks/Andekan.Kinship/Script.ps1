$Object1 = Invoke-RestMethod -Uri 'https://app.kinship.io/index.php?action=download_addin&func=get_assets&version=release'
# EXE
$Object2 = $Object1.Where({ $_.fileName -match 'KinshipSetup' -and $_.extension -eq 'exe' }, 'First')[0]
# MSI
$Object3 = $Object1.Where({ $_.fileName -match 'KinshipInstaller' -and $_.extension -eq 'msi' }, 'First')[0]

if ($Object2.version -ne $Object3.version) {
  $this.Log("Inconsistent versions: EXE: $($Object2.version), MSI: $($Object3.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType   = 'inno'
  InstallerUrl    = "https://app.kinship.io/download/$($Object2.name)"
  InstallerSha256 = $Object2.SHA256
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = "https://app.kinship.io/download/$($Object3.name)"
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
