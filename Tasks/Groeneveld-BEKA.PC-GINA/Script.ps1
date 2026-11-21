$Page = Invoke-WebRequest -Uri 'https://www.groeneveld-beka.com/software/'
$Link = $Page.Links.Where({ try { $_.href -match 'PC-?GINA' -and $_.href -notmatch 'BreakAlube' -and $_.href.EndsWith('.zip') } catch {} }, 'First')[0].href

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType        = 'zip'
  NestedInstallerType  = 'burn'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "$($Link | Split-Path -LeafBase).exe" })
  InstallerUrl         = $Link
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
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
