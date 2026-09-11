$Prefix = 'https://fragstats.org/index.php/downloads'
$Page = Invoke-WebRequest -Uri $Prefix

# Installer
$InstallerUrl = Join-Uri $Prefix $Page.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('x64') -and $_.href -match 'setup' } catch {} }, 'First')[0].href | ConvertTo-UnescapedUri
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'inno'
  NestedInstallerFiles = @(@{ RelativeFilePath = "$($InstallerUrl | Split-Path -LeafBase).exe" })
  InstallerUrl         = $InstallerUrl

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
