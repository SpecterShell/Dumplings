$Object1 = Invoke-WebRequest -Uri 'https://www.rathlev-home.de/tools/prog-e.html'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'InnoUnpacker(?:\s|&nbsp;)*(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://www.rathlev-home.de/tools/' $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('innounpacker') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
