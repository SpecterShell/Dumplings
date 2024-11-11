$Object1 = Invoke-WebRequest -Uri 'https://icecatbrowser.org/all_downloads.html'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Icecat Version:(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://icecatbrowser.org/' $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('installer') -and -not $_.href.Contains('aarch64') } catch {} }, 'First')[0].href
  ProductCode  = "IceCat $($this.CurrentState.Version) (x64 en-US)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri 'https://icecatbrowser.org/' $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('installer') -and $_.href.Contains('aarch64') } catch {} }, 'First')[0].href
  ProductCode  = "IceCat $($this.CurrentState.Version) (AArch64 en-US)"
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
