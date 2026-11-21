$Object1 = Invoke-WebRequest -Uri 'https://www.cutepdf.com/Products/CutePDF/writer.asp'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Ver\. (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerUrl           = Join-Uri 'https://www.cutepdf.com/Products/CutePDF/writer.asp' $Object1.Links.Where({ try { $_.href.EndsWith('.zip') } catch {} }, 'First')[0].href
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = " $($this.CurrentState.Version)"
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
