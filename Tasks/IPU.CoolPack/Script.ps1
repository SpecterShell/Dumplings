$Object1 = Invoke-WebRequest -Uri 'https://www.ipu.dk/products/coolpack/'
$InstallerLink = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($InstallerLink.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = '{0}.{1}{2}' -f $this.CurrentState.Version.Split('.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerLink.href
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
