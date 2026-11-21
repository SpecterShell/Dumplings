$Prefix = 'https://easymorph.com/download/all-downloads'
$Object1 = Invoke-WebRequest -Uri $Prefix
$Link = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('EMHub.') -and $_.href -match 'Setup' } catch {} }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Link.href
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'EasyMorph Hub v(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'EMHub.Setup.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'EMHub.Setup.exe'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromExe
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
