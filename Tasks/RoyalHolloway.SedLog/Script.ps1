$Object1 = Invoke-WebRequest -Uri 'https://sedlog.rhul.ac.uk/download.html'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('setup') } catch {} }, 'First')[0].href | ConvertTo-Https
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'sedlog-(\d+(\.\d+)+)[-.]').Groups[1].Value

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
