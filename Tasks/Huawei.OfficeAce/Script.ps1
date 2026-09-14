$Page = Invoke-WebRequest -Uri 'https://www.huaweicloud.com/product/agentarts/officeace.html'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Page.Links.Where({ try { $_.href -match 'OfficeAce' -and $_.href.EndsWith('.exe') -and $_.href -match 'x64' -and $_.href -match 'setup' } catch {} }, 'First')[0].href
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
