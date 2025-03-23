$Object1 = Invoke-WebRequest -Uri 'https://www.esbconsult.com/esbcalc/esbprogcalcpro.htm'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and -not $_.href.Contains('port') -and -not $_.href.Contains('nosetup') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'ESBProgCalc&trade; Pro Trial v(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.Content, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFile2 = $InstallerFile | Expand-TempArchive | Join-Path -ChildPath 'setup.exe'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromExe
    Remove-Item -Path $InstallerFile2 -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
