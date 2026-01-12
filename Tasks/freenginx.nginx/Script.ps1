$Prefix = 'https://freenginx.org/en/download.html'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.outerHTML -match 'windows' } catch {} }, 'First')[0].href
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($InstallerUrl | Split-Path -LeafBase)\nginx.exe"
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
