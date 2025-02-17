$Object1 = Invoke-WebRequest -Uri 'https://caramba-switcher.com/update'
# $Object1 = Invoke-RestMethod -Uri 'https://cdn.caramba-switcher.com/files/update.windows.xml'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(20\d{1,2}\.\d{1,2}\.\d{1,2})').Groups[1].Value

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
