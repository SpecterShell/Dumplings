$Object1 = Invoke-WebRequest -Uri 'https://www.thermofisher.com/software-em-3d-vis/customerportal/download-center/amira-avizo-3d-installers/'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Amira-Avizo 3D (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
  ProductCode            = "Amira Avizo 3D Software $($this.CurrentState.Version)_is1"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = "$($this.CurrentState.Version)."
    }
  )
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
