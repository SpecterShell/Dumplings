$Object1 = Invoke-RestMethod -Uri 'https://desktop.figma.com/win/RELEASE.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = "https://desktop.figma.com/win/build/Figma-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'exe'
  InstallerUrl  = "https://desktop.figma.com/win-arm/build/Figma-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += $InstallerX64WiX = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://desktop.figma.com/win/build/Figma-$($this.CurrentState.Version).msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFileX64WiX = Get-TempFile -Uri $InstallerX64WiX.InstallerUrl
    # InstallerSha256
    $InstallerX64WiX['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX64WiX -Algorithm SHA256).Hash
    # ProductCode
    $InstallerX64WiX['ProductCode'] = "$($InstallerFileX64WiX | Read-ProductCodeFromMsi).msq"

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
