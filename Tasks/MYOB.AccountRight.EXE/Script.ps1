$Object1 = $Global:DumplingsStorage.MYOBApps.items.Where({ $_.fields.product -eq 'AccountRight PC Edition' }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object1.fields.version, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.fields.installerLink
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'RELEASES' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'RELEASES'
    # RealVersion
    $this.CurrentState.RealVersion = Get-Content -Path $InstallerFile2 -Raw | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { [RawVersion]$_.Version } -Bottom 1 | Select-Object -ExpandProperty Version

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
