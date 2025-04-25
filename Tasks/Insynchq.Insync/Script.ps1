$Object1 = (Invoke-WebRequest -Uri 'https://cdn.insynchq.com/web/webflow/js/windows_download_links.js').Content | Get-EmbeddedJson -StartsFrom 'var windows_download_links = ' | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.desktop_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.builds
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
