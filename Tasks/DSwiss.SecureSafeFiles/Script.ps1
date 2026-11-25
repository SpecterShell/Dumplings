$Object1 = Invoke-PlaywrightFetch -Uri 'https://securesafe.com/' -Headless -Stealth -SolveCloudflare | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Where({ try { $_.href.Contains('.exe') -and $_.href -match 'SecureSafe-Files' } catch {} }, 'First')[0].href | Split-Uri -LeftPart 'Path'
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
