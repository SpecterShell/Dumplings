$Object1 = (Invoke-WebRequest -Uri 'https://www.visual-planning.com/en/support-portal/vpdesk-new-launcher').Content | Get-EmbeddedJson -StartsFrom 'var et_link_options_data = ' | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Where({ try { $_.url.EndsWith('.msi') } catch {} }, 'First')[0].url
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
