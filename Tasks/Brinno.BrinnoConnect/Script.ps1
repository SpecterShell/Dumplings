$Object1 = Invoke-WebRequest -Uri 'https://brinno.com/pages/brinno-bcc2000-time-lapse-camera-command-center'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('Installer') } catch {} }, 'First')[0].href
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($InstallerUrl | Split-Path -LeafBase).exe"
    }
  )
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
