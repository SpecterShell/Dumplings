$Object1 = Invoke-WebRequest -Uri 'https://www.rathlev-home.de/tools/prog-e.html'
$Object2 = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('innounp-1') } catch {} }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object2.outerHTML, 'version(?:\s|&nbsp;)*(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://www.rathlev-home.de/tools/' $Object2.href
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
