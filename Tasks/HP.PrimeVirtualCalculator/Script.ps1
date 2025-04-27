$Object1 = Invoke-RestMethod -Uri 'https://updates.moravia-consulting.com/update.xml'

# Version
$this.CurrentState.Version = $Object1.update.site.os.Where({ $_.name -eq 'windows' }, 'First')[0].app.f

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://' + $Object1.update.site.root.Replace('%1',
    $Object1.update.site.os.Where({ $_.name -eq 'windows' }, 'First')[0].app.name.Replace('%1',
      $Object1.update.site.os.Where({ $_.name -eq 'windows' }, 'First')[0].app.f
    )
  )
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
