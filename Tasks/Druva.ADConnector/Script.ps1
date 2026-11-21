$Object1 = (Invoke-RestMethod -Uri 'https://downloads.druva.com/insync/js/data.json').Where({ $_.title -eq 'Windows AD/LDAP Connector' }, 'First')[0].installerDetails[0]

# Version
$this.CurrentState.Version = $Object1.installerVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadURL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

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
